import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/log.dart';

import '../../core/navigation.dart';
import '../../generated/l10n.dart';
import '../actions/action_executor.dart';
import '../actions/device_actions.dart';
import '../automation/background_automation.dart';
import '../server/server_session.dart';
import '../startup/startup_controller.dart';
import 'push_history.dart';
import 'push_payload.dart';
import 'push_service.dart';

/// Decides what to do with each push from n8n once the app is ready:
/// - "Run" button on the notification → run, then return to the background.
/// - foreground with auto-run enabled → run directly.
/// - otherwise → list the actions and ask the user.
///
/// Every handled push is also recorded in [PushHistory] (the inbox).
class PushEventHandler extends StatefulWidget {
  const PushEventHandler({
    super.key,
    required this.onOpenApp,
    required this.child,
  });

  final void Function(String appId) onOpenApp;
  final Widget child;

  @override
  State<PushEventHandler> createState() => _PushEventHandlerState();
}

class _PushEventHandlerState extends State<PushEventHandler> {
  StreamSubscription<PushEvent>? _subscription;
  late final PushHistory _history;

  // Events are handled one at a time so dialogs never stack.
  Future<void> _queue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _history = context.read<PushHistory>();
    unawaited(_history.load());
    final push = context.read<PushService>();
    context.read<StartupController>().done.then((_) {
      if (!mounted) return;
      _subscription = push.events.listen((event) {
        unawaited(_history.record(event.payload, PushStatus.pending));
        _queue = _queue.then((_) => _handle(event)).catchError((Object _) {});
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handle(PushEvent event) async {
    // Let the first route settle before showing dialogs over it.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final executor = context.read<ActionExecutor>();
    final device = context.read<DeviceActions>();
    final push = context.read<PushService>();
    final payload = event.payload;
    final actions = payload.actions;

    // Pushes are only for the account connected right now: after a sign-out
    // or an account change the old account's pushes are dropped unseen.
    final session = context.read<ServerSession>();
    final decision = await BackgroundAutomation.decide(
      payload,
      server: session.baseUrl,
      email: session.user?.email,
    );
    if (!mounted) return;
    if (decision == AutomationDecision.drop) {
      appLog('Push', 'dropped a push not meant for the connected account');
      return;
    }
    if (decision == AutomationDecision.run) {
      // Allowed automation: same as in the background, without a dialog.
      final ok = await executor.run(
        actions,
        askConfirmation: false,
        appId: payload.appId,
        automaticOnly: true,
      );
      await _recordRun(payload, ok);
      return;
    }

    if (actions.isEmpty) {
      await _history.record(payload, PushStatus.executed);
      final app = payload.appId;
      if (event.origin == PushOrigin.tap && app != null) {
        widget.onOpenApp(app);
      } else if (event.origin == PushOrigin.foreground) {
        await push.showSimple(payload.title, payload.body);
      }
      return;
    }

    switch (event.origin) {
      case PushOrigin.runButton:
        final ok = await executor.run(actions, appId: payload.appId);
        await _recordRun(payload, ok);
        if (ok) await device.moveToBackground();
      case PushOrigin.foreground when push.autoRun:
        showAppSnackBar(payload.title);
        await _recordRun(
          payload,
          await executor.run(actions, appId: payload.appId),
        );
      case PushOrigin.foreground:
      case PushOrigin.tap:
        if (await _confirm(payload)) {
          await _recordRun(
            payload,
            await executor.run(actions, appId: payload.appId),
          );
        } else {
          await _history.record(payload, PushStatus.ignored);
        }
    }
  }

  Future<void> _recordRun(PushPayload payload, bool ok) =>
      _history.record(payload, ok ? PushStatus.executed : PushStatus.failed);

  Future<bool> _confirm(PushPayload payload) async {
    final context = rootOverlayContext;
    if (context == null) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.bolt),
        title: Text(
          payload.title.isEmpty ? l10n.pushDialogTitle : payload.title,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (payload.body.isNotEmpty) ...[
              Text(payload.body),
              const SizedBox(height: 12),
            ],
            Text(
              l10n.pushDialogIntro,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            for (final action in payload.actions)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${describeAction(action)}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.pushDialogIgnore),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pushDialogRun),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
