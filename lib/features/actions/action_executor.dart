import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/json.dart';
import '../../core/log.dart';
import '../../core/navigation.dart';
import '../../core/template.dart';
import '../../generated/l10n.dart';
import '../alarms/alarm_engine.dart';
import '../apps/app_models.dart';
import '../device_context/device_context.dart';
import '../server/error_messages.dart';
import '../server/server_session.dart';
import 'action_spec.dart';
import 'device_actions.dart';

/// Error with a message ready to show to the user.
class ActionException implements Exception {
  const ActionException(this.message);

  final String message;

  @override
  String toString() => 'ActionException($message)';
}

/// The open app screen, for actions that change the UI (`submit`,
/// `navigate`, ...). Push actions run without one.
abstract class ActionHost {
  Map<String, dynamic> get state;

  /// [params] are the already resolved parameters of a `submit` action.
  Future<void> submit(Map<String, dynamic> params);

  void navigate(String screen);

  /// Pops one screen of the app; leaves the app when on its first screen.
  void back();

  Future<void> reload();

  void mergeState(Map<String, dynamic> values);
}

/// Runs action lists coming from app specs, submit responses and pushes.
class ActionExecutor {
  ActionExecutor({
    required DeviceActions device,
    required Future<void> Function(String title, String body) notify,
    required void Function(String appId) openApp,
    ServerSession? session,
  }) : _device = device,
       _notify = notify,
       _openApp = openApp,
       _session = session;

  final DeviceActions _device;
  final Future<void> Function(String title, String body) _notify;
  final void Function(String appId) _openApp;

  /// For `report`, which sends phone data to the n8n server.
  final ServerSession? _session;

  /// Runs [actions] in order, stopping at the first failure or cancelled
  /// confirmation. Errors are shown to the user; returns whether all ran.
  ///
  /// [appId] is the n8n app the actions belong to (alarms are kept per app).
  /// With [automaticOnly] (automations, background pushes) only
  /// [automaticActionTypes] may run.
  Future<bool> run(
    List<ActionSpec> actions, {
    ActionHost? host,
    bool askConfirmation = true,
    String? appId,
    bool automaticOnly = false,
  }) async {
    for (final action in actions) {
      final state = host?.state ?? const <String, dynamic>{};
      final params = asMap(Template.resolve(action.params, state));
      final confirm = action.confirm ?? _implicitConfirm(action.type);
      if (askConfirmation && confirm != null) {
        final accepted = await _confirm(confirm, state);
        if (!accepted) return false;
      }
      try {
        if (automaticOnly && !automaticActionTypes.contains(action.type)) {
          throw UnsupportedError('${action.type} cannot run automatically');
        }
        await _runOne(
          action.type,
          params,
          host,
          appId: appId,
          automaticOnly: automaticOnly,
        );
      } catch (e) {
        appLog('Actions', '${action.type} failed: $e');
        showAppSnackBar(describeError(e), error: true);
        return false;
      }
    }
    return true;
  }

  /// Actions that always ask, even when the spec sets no `confirm`: reading
  /// the clipboard could leak passwords or codes to n8n.
  static ConfirmSpec? _implicitConfirm(String type) => type == 'read_clipboard'
      ? ConfirmSpec(message: AppLocalizations.current.confirmReadClipboard)
      : null;

  Future<void> _runOne(
    String type,
    Map<String, dynamic> params,
    ActionHost? host, {
    String? appId,
    bool automaticOnly = false,
  }) async {
    final l10n = AppLocalizations.current;
    ActionHost requireHost() =>
        host ?? (throw ActionException(l10n.errorActionNeedsScreen(type)));

    switch (type) {
      case 'schedule_alarm':
        final at = DateTime.tryParse(asString(params['at']) ?? '');
        if (at == null) throw ArgumentError('schedule_alarm: missing "at"');
        await AlarmEngine.schedule(
          appId: appId ?? 'n8n',
          id: asString(params['id']) ?? 'default',
          at: at,
          label: asString(params['label']),
          body: asString(params['body']),
        );
        final local = at.toLocal();
        showAppSnackBar(
          l10n.actionScheduledAlarm(_formatTime(local.hour, local.minute)),
        );
      case 'cancel_alarm':
        await AlarmEngine.cancel(
          appId: appId ?? 'n8n',
          id: asString(params['id']) ?? 'default',
        );
      case 'report':
        final session = _session;
        final path = asString(params['path']);
        if (session == null || path == null || path.isEmpty) {
          throw ArgumentError('report: missing path or session');
        }
        final include = asList(
          params['include'],
        ).map(asString).whereType<String>();
        final json = await session.request(
          'POST',
          path,
          body: {
            ...await DeviceContext.collect(
              include.isEmpty ? const ['location'] : include,
            ),
            'app': appId,
            'data': asMap(params['data']),
          },
          timeout: const Duration(seconds: 60),
        );
        // n8n can answer with more actions (e.g. the alarm it just computed).
        final next = ActionResponse.fromJson(json).actions;
        if (next.isNotEmpty) {
          final ok = await run(
            next,
            askConfirmation: !automaticOnly,
            appId: appId,
            automaticOnly: automaticOnly,
          );
          if (!ok) throw ActionException(l10n.errorActionChainFailed);
        }
      case 'request_permission':
        final permission = DevicePermission.fromName(
          asString(params['permission']),
        );
        if (permission == null) {
          throw ArgumentError('request_permission: unknown permission');
        }
        await DeviceContext.request(permission);
      case 'submit':
        await requireHost().submit(params);
      case 'navigate':
        final screen = asString(params['screen']);
        if (screen == null) throw ArgumentError('navigate: missing screen');
        requireHost().navigate(screen);
      case 'back':
        requireHost().back();
      case 'reload':
        await requireHost().reload();
      case 'set_state':
        requireHost().mergeState(asMap(params['values'] ?? params['state']));
      case 'open_app':
        final app = asString(params['app']);
        if (app == null || app.isEmpty) {
          throw ArgumentError('open_app: missing app');
        }
        _openApp(app);
      case 'toast':
        final message = asString(params['message']);
        if (message != null && message.isNotEmpty) showAppSnackBar(message);
      case 'dialog':
        await _showDialog(
          asString(params['title']),
          asString(params['message']) ?? '',
        );
      case 'notify':
        await _notify(
          asString(params['title']) ?? l10n.appTitle,
          asString(params['body']) ?? '',
        );
      case 'set_alarm':
        final time = _parseTime(params);
        await _device.setAlarm(
          hour: time.$1,
          minute: time.$2,
          label: asString(params['label']),
          days: asList(params['days']).map(asInt).whereType<int>().toList(),
          vibrate: params.containsKey('vibrate')
              ? asBool(params['vibrate'])
              : null,
          skipUi: asBool(params['skipUi'], fallback: true),
        );
        showAppSnackBar(l10n.actionAlarmDone(_formatTime(time.$1, time.$2)));
      case 'set_timer':
        final seconds =
            asInt(params['seconds']) ?? ((asInt(params['minutes']) ?? 0) * 60);
        await _device.setTimer(
          seconds: seconds,
          label: asString(params['label']),
          skipUi: asBool(params['skipUi'], fallback: true),
        );
      case 'calendar_event':
        final title = asString(params['title']);
        final start = DateTime.tryParse(asString(params['start']) ?? '');
        if (title == null || start == null) {
          throw ArgumentError('calendar_event: title and start are required');
        }
        await _device.addCalendarEvent(
          title: title,
          start: start.toLocal(),
          end: DateTime.tryParse(asString(params['end']) ?? '')?.toLocal(),
          location: asString(params['location']),
          description: asString(params['description']),
          allDay: asBool(params['allDay']),
        );
      case 'open_url':
        final url = Uri.tryParse(asString(params['url']) ?? '');
        if (url == null || url.scheme.isEmpty) {
          throw ArgumentError('open_url: invalid url');
        }
        await _device.openUrl(url);
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: asString(params['text']) ?? ''),
        );
        showAppSnackBar(l10n.actionCopied);
      case 'share':
        await _device.share(
          text: _required(params, 'text', 'share'),
          subject: asString(params['subject']),
          chooserTitle: l10n.actShareChooser,
        );
      case 'dial':
        await _device.dial(_required(params, 'number', 'dial'));
      case 'sms':
        await _device.sms(
          _required(params, 'number', 'sms'),
          body: asString(params['body']),
        );
      case 'email':
        await _device.email(
          to: _required(params, 'to', 'email'),
          subject: asString(params['subject']),
          body: asString(params['body']),
        );
      case 'maps':
        await _device.openMaps(
          query: asString(params['query']),
          lat: asDouble(params['lat']),
          lng: asDouble(params['lng']),
          label: asString(params['label']),
          navigate: asBool(params['navigate']),
        );
      case 'vibrate':
        await _device.vibrate(style: asString(params['style']));
      case 'show_alarms':
        await _device.showAlarms();
      case 'open_settings':
        await _device.openSettings(_required(params, 'panel', 'open_settings'));
      case 'launch_app':
        await _device.launchApp(_required(params, 'package', 'launch_app'));
      case 'read_clipboard':
        final activeHost = requireHost();
        final key = _required(params, 'key', 'read_clipboard');
        final clip = await Clipboard.getData(Clipboard.kTextPlain);
        activeHost.mergeState({key: clip?.text ?? ''});
      default:
        throw UnsupportedError('Unknown action type: $type');
    }
  }

  Future<bool> _confirm(ConfirmSpec confirm, Map<String, dynamic> state) async {
    final context = rootOverlayContext;
    if (context == null) return false;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          Template.render(confirm.title ?? l10n.confirmActionTitle, state),
        ),
        content: Text(Template.render(confirm.message, state)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.dialogActionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              Template.render(
                confirm.confirmLabel ?? l10n.dialogActionConfirm,
                state,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showDialog(String? title, String message) async {
    final context = rootOverlayContext;
    if (context == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// Accepts `hour` + `minute` or `time: "HH:mm"`.
(int, int) _parseTime(Map<String, dynamic> params) {
  final time = asString(params['time']);
  if (time != null) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time.trim());
    if (match != null) {
      return (int.parse(match.group(1)!), int.parse(match.group(2)!));
    }
  }
  final hour = asInt(params['hour']);
  final minute = asInt(params['minute']) ?? 0;
  if (hour == null) throw ArgumentError('set_alarm: missing hour/time');
  return (hour, minute);
}

String _formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// A string parameter that must not be empty.
String _required(Map<String, dynamic> params, String key, String action) {
  final value = asString(params[key]);
  if (value == null || value.trim().isEmpty) {
    throw ArgumentError('$action: missing $key');
  }
  return value;
}

/// Short place name for the description of a maps action.
String _mapPlace(Map<String, dynamic> params) {
  final query = (asString(params['query']) ?? '').trim();
  if (query.isNotEmpty) return query;
  final lat = asDouble(params['lat']);
  final lng = asDouble(params['lng']);
  if (lat == null || lng == null) return '?';
  return '$lat,$lng';
}

/// One-line, localized description of an action, for the push confirmation
/// dialog ("Set an alarm at 07:30 · Gym").
String describeAction(ActionSpec action) {
  final l10n = AppLocalizations.current;
  final p = action.params;
  switch (action.type) {
    case 'schedule_alarm':
      final at = DateTime.tryParse(asString(p['at']) ?? '')?.toLocal();
      final label = asString(p['label']);
      return l10n.describeScheduleAlarm(
            at == null ? '?' : _formatTime(at.hour, at.minute),
          ) +
          (label == null || label.isEmpty ? '' : ' · $label');
    case 'cancel_alarm':
      return l10n.describeCancelAlarm;
    case 'report':
      return l10n.describeReport;
    case 'request_permission':
      return l10n.describeRequestPermission(asString(p['permission']) ?? '');
    case 'set_alarm':
      String time;
      try {
        final parsed = _parseTime(p);
        time = _formatTime(parsed.$1, parsed.$2);
      } on ArgumentError {
        time = '?';
      }
      final label = asString(p['label']);
      return l10n.describeAlarm(time) +
          (label == null || label.isEmpty ? '' : ' · $label');
    case 'set_timer':
      final seconds = asInt(p['seconds']) ?? ((asInt(p['minutes']) ?? 0) * 60);
      final duration = seconds >= 60 && seconds % 60 == 0
          ? '${seconds ~/ 60} min'
          : '$seconds s';
      return l10n.describeTimer(duration);
    case 'calendar_event':
      return l10n.describeCalendarEvent(asString(p['title']) ?? '');
    case 'open_url':
      return l10n.describeOpenUrl(asString(p['url']) ?? '');
    case 'notify':
      return l10n.describeNotify(asString(p['title']) ?? '');
    case 'copy':
      return l10n.describeCopy;
    case 'open_app':
      return l10n.describeOpenApp(asString(p['app']) ?? '');
    case 'share':
      return l10n.actDescribeShare(asString(p['text']) ?? '');
    case 'dial':
      return l10n.actDescribeDial(asString(p['number']) ?? '');
    case 'sms':
      return l10n.actDescribeSms(asString(p['number']) ?? '');
    case 'email':
      return l10n.actDescribeEmail(asString(p['to']) ?? '');
    case 'maps':
      return asBool(p['navigate'])
          ? l10n.actDescribeNavigate(_mapPlace(p))
          : l10n.actDescribeMap(_mapPlace(p));
    case 'vibrate':
      return l10n.actDescribeVibrate;
    case 'show_alarms':
      return l10n.actDescribeShowAlarms;
    case 'open_settings':
      return l10n.actDescribeOpenSettings(asString(p['panel']) ?? '');
    case 'launch_app':
      return l10n.actDescribeLaunchApp(asString(p['package']) ?? '');
    case 'read_clipboard':
      return l10n.actDescribeReadClipboard(asString(p['key']) ?? '');
    case 'toast':
    case 'dialog':
      return asString(p['message']) ?? action.type;
    default:
      return action.type;
  }
}
