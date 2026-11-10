import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/json.dart';
import '../../core/log.dart';
import '../../core/navigation.dart';
import '../../core/template.dart';
import '../../generated/l10n.dart';
import '../actions/action_executor.dart';
import '../actions/action_spec.dart';
import '../device_context/device_context.dart';
import '../server/error_messages.dart';
import 'app_models.dart';
import 'apps_cache.dart';
import 'apps_repository.dart';
import 'spec_view.dart';

/// Runs one n8n app: fetches its spec, keeps its state and screen stack, and
/// executes the actions its buttons and workflow responses ask for.
///
/// A spec with `refreshSeconds` is reloaded in the background (see
/// [_autoRefresh]); when the network is down the saved copy is shown instead.
class AppRunnerPage extends StatefulWidget {
  const AppRunnerPage({super.key, required this.appId});

  final String appId;

  @override
  State<AppRunnerPage> createState() => _AppRunnerPageState();
}

class _AppRunnerPageState extends State<AppRunnerPage>
    with WidgetsBindingObserver
    implements ActionHost {
  AppSummary? _app;
  AppSpec? _spec;
  Object? _error;
  bool _loading = true;

  /// Non-null while a submit is in flight (text shown in the overlay).
  String? _busyLabel;

  /// When the shown data was saved, while it comes from the offline cache.
  DateTime? _cachedAt;

  /// Time of the last successful load (AppBar subtitle).
  DateTime? _updatedAt;

  Timer? _refreshTimer;
  bool _autoRefreshing = false;

  /// Bumped by every load, spec change and submit; a background refresh that
  /// started before one of them is discarded.
  int _loadGeneration = 0;
  bool _resumed = true;

  final Map<String, dynamic> _state = {};
  final List<String> _stack = [];

  /// Scroll offset of each screen, so going back returns to where the user
  /// was and a newly opened screen starts at the top.
  final Map<String, double> _offsets = {};

  /// Controller of the screen on top, recreated when another screen shows.
  ScrollController? _scroll;
  String? _scrollScreen;

  /// While a workflow response rebuilds the stack, the screens that were open
  /// before it: they keep their saved offsets when the stack passes through
  /// them again. Any other screen opened then starts at the top.
  Set<String>? _keepOffsets;

  AppsRepository get _repository => context.read<AppsRepository>();
  ActionExecutor get _executor => context.read<ActionExecutor>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scroll?.dispose();
    super.dispose();
  }

  /// Controller for [screen]. A new one (with a new list, see [_body]) is made
  /// when the screen on top changes. Every list it attaches to (also after a
  /// loading spinner replaced it) starts at the screen's saved offset.
  ScrollController _scrollFor(String screen) {
    final current = _scroll;
    if (current != null && _scrollScreen == screen) return current;
    if (current != null) {
      // The old list is unmounted in this frame; dispose its controller after.
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    final controller = _SavedOffsetController(() => _offsets[screen] ?? 0);
    controller.addListener(() {
      if (controller.hasClients) _offsets[screen] = controller.offset;
    });
    _scrollScreen = screen;
    return _scroll = controller;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
  }

  Future<void> _load() async {
    _loadGeneration++;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = _app ?? await _repository.find(widget.appId);
      final result = await _repository.loadSpec(app);
      if (!mounted) return;
      setState(() {
        _app = app;
        _applySpec(result.value);
        _markLoaded(result.savedAt);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _applySpec(AppSpec spec) {
    _loadGeneration++;
    _spec = spec;
    _state
      ..clear()
      ..addAll(spec.initialState);
    _specState = _snapshot(spec.initialState);
    _stack
      ..clear()
      ..add(spec.start);
    _restartRefreshTimer();
  }

  /// Initial state of the spec currently shown, to tell server values from
  /// values the user (or a response) changed since.
  Map<String, dynamic> _specState = const {};

  /// Silent reload: the new initial state updates the keys it sets unless the
  /// user changed them since the last load (a form being filled in keeps its
  /// values); the screen stack survives when its screens do.
  void _mergeSpec(AppSpec spec) {
    final keepStack =
        _stack.isNotEmpty && _stack.every(spec.screens.containsKey);
    _spec = spec;
    spec.initialState.forEach((key, value) {
      final untouched =
          !_state.containsKey(key) || _sameValue(_state[key], _specState[key]);
      if (untouched) _state[key] = value;
    });
    _specState = _snapshot(spec.initialState);
    if (!keepStack) {
      _stack
        ..clear()
        ..add(spec.start);
    }
    _restartRefreshTimer();
  }

  static Map<String, dynamic> _snapshot(Map<String, dynamic> state) {
    try {
      return asMap(jsonDecode(jsonEncode(state)));
    } on JsonUnsupportedObjectError {
      return Map<String, dynamic>.from(state);
    }
  }

  static bool _sameValue(Object? a, Object? b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } on JsonUnsupportedObjectError {
      return a == b;
    }
  }

  void _markLoaded(DateTime? savedAt) {
    _cachedAt = savedAt;
    _updatedAt = savedAt ?? DateTime.now();
  }

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    final seconds = _spec?.refreshSeconds;
    _refreshTimer = seconds == null
        ? null
        : Timer.periodic(Duration(seconds: seconds), (_) => _autoRefresh());
  }

  /// Timer tick. Skipped while a submit or a manual load runs, while the app
  /// is in the background, or while another route covers this page. Errors
  /// are silent: the current screen stays as it is.
  Future<void> _autoRefresh() async {
    final app = _app;
    if (app == null ||
        !mounted ||
        _autoRefreshing ||
        _loading ||
        _busyLabel != null ||
        !_resumed ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _autoRefreshing = true;
    final generation = _loadGeneration;
    try {
      final result = await _repository.loadSpec(app);
      // Re-check: a submit or a manual reload may have run meanwhile.
      if (!mounted ||
          _loading ||
          _busyLabel != null ||
          generation != _loadGeneration) {
        return;
      }
      setState(() {
        _mergeSpec(result.value);
        _markLoaded(result.savedAt);
      });
    } catch (e) {
      appLog('AppRunner', 'auto refresh failed: $e');
    } finally {
      _autoRefreshing = false;
    }
  }

  ScreenSpec? get _screen {
    final spec = _spec;
    return spec == null || _stack.isEmpty ? null : spec.screen(_stack.last);
  }

  // ---- ActionHost ----------------------------------------------------------

  @override
  Map<String, dynamic> get state => _state;

  @override
  void mergeState(Map<String, dynamic> values) {
    if (values.isEmpty || !mounted) return;
    setState(() => _state.addAll(values));
  }

  @override
  void navigate(String screen) {
    final spec = _spec;
    if (spec == null || !spec.screens.containsKey(screen)) {
      throw ArgumentError('navigate: unknown screen $screen');
    }
    setState(() {
      final index = _stack.indexOf(screen);
      if (index >= 0) {
        _stack.removeRange(index + 1, _stack.length);
      } else {
        // A screen opened anew starts at the top.
        if (!(_keepOffsets?.contains(screen) ?? false)) {
          _offsets.remove(screen);
        }
        _stack.add(screen);
      }
    });
  }

  @override
  void back() {
    if (_stack.length > 1) {
      setState(_stack.removeLast);
    } else if (mounted) {
      context.pop();
    }
  }

  @override
  Future<void> reload() => _load();

  @override
  Future<void> submit(Map<String, dynamic> params) async {
    final l10n = AppLocalizations.of(context);
    final path = asString(params['path']) ?? asString(params['url']);
    if (path == null || path.isEmpty) {
      throw ArgumentError('submit: missing path');
    }
    final missing = _missingRequiredField();
    if (missing != null) throw ActionException(l10n.fieldRequired(missing));

    _loadGeneration++;
    setState(() => _busyLabel = asString(params['loading']) ?? '');
    try {
      final response = await _repository.submit(
        path,
        asString(params['method']) ?? 'POST',
        {
          ..._payload(params),
          // `include: ["location"]` adds phone data under `_device`.
          if (asList(params['include']).isNotEmpty)
            '_device': await DeviceContext.collect(
              asList(params['include']).map(asString).whereType<String>(),
            ),
        },
      );
      if (!mounted) return;
      await _applyResponse(response);
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  /// Explicit `body` (already template-resolved), else the `keys` listed, else
  /// the whole state except keys starting with `_` (local-only values).
  Map<String, dynamic> _payload(Map<String, dynamic> params) {
    final body = params['body'];
    if (body is Map) return asMap(body);
    final keys = asList(params['keys']).map(asString).whereType<String>();
    if (keys.isNotEmpty) {
      return {for (final key in keys) key: _state[key]};
    }
    return Map.fromEntries(
      _state.entries.where((entry) => !entry.key.startsWith('_')),
    );
  }

  String? _missingRequiredField() {
    for (final component in _screen?.components ?? const []) {
      final key = asString(component['key']);
      if (key == null || !asBool(component['required'])) continue;
      final value = _state[key];
      if (value == null || (value is String && value.trim().isEmpty)) {
        return Template.render(asString(component['label']) ?? key, _state);
      }
    }
    return null;
  }

  Future<void> _applyResponse(ActionResponse response) async {
    // A response may replace the spec and rebuild the stack with `screen` and
    // `navigate` actions (or `reload` + `navigate`). The screens that were
    // open keep their positions (a refresh of the same screen stays where it
    // was); a screen that was not open starts at the top. Nested submits
    // among the actions add to the set and restore it when they finish.
    final previous = _keepOffsets;
    _keepOffsets = {..._stack, ...?previous};
    try {
      setState(() {
        // A live answer: the screen is no longer showing saved data.
        _cachedAt = null;
        final spec = response.spec;
        if (spec != null) _applySpec(spec);
        _state.addAll(response.state);
      });
      final screen = response.screen;
      if (screen != null) navigate(screen);
      final message = response.message;
      if (message != null && message.isNotEmpty) showAppSnackBar(message);
      if (response.actions.isNotEmpty) {
        await _executor.run(response.actions, host: this, appId: widget.appId);
      }
    } finally {
      _keepOffsets = previous;
    }
  }

  // ---- UI ------------------------------------------------------------------

  Future<void> _runActions(List<ActionSpec> actions) =>
      _executor.run(actions, host: this, appId: widget.appId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screen = _screen;
    final title = screen?.title ?? _spec?.title ?? _app?.name ?? '';
    final updatedAt = _updatedAt;

    return PopScope(
      canPop: _stack.length <= 1 && _busyLabel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _busyLabel == null && _stack.length > 1) back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: updatedAt == null
              ? Text(title)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, overflow: TextOverflow.ellipsis),
                    Text(
                      l10n.runnerUpdatedAt(formatSavedTime(updatedAt)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.reloadTooltip,
              onPressed: _loading || _busyLabel != null ? null : _load,
            ),
          ],
        ),
        body: Stack(
          children: [
            _body(context, screen),
            if (_busyLabel != null) _BusyOverlay(label: _busyLabel!),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ScreenSpec? screen) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null || screen == null) {
      return _ErrorView(
        message: describeError(error ?? const FormatException()),
        onRetry: _load,
      );
    }
    final cachedAt = _cachedAt;
    final screenId = _stack.last;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        // One list per screen, so each starts at its own saved offset.
        key: ValueKey('screen:$screenId'),
        controller: _scrollFor(screenId),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (cachedAt != null) _OfflineBanner(savedAt: cachedAt),
          SpecView(
            components: screen.components,
            state: _state,
            enabled: _busyLabel == null,
            onChanged: (key, value) => setState(() => _state[key] = value),
            onActions: _runActions,
            appId: widget.appId,
          ),
        ],
      ),
    );
  }
}

/// Shown above the spec while its data comes from the offline cache.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.savedAt});

  final DateTime savedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              ).runnerOfflineBanner(formatSavedTime(savedAt)),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retryButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scroll controller whose initial offset is read when a list attaches, so a
/// list rebuilt after a spinner or an error starts at the latest saved offset.
class _SavedOffsetController extends ScrollController {
  _SavedOffsetController(this._saved);

  final double Function() _saved;

  @override
  double get initialScrollOffset => _saved();
}
