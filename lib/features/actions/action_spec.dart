import '../../core/json.dart';

/// Optional confirmation shown before an action runs.
class ConfirmSpec {
  const ConfirmSpec({required this.message, this.title, this.confirmLabel});

  /// Accepts `"¿Seguro?"` or `{"title", "message", "confirmLabel"}`.
  static ConfirmSpec? fromJson(Object? json) {
    if (json is String && json.trim().isNotEmpty) {
      return ConfirmSpec(message: json.trim());
    }
    final map = asMap(json);
    final message = asString(map['message']);
    if (message == null || message.isEmpty) return null;
    return ConfirmSpec(
      message: message,
      title: asString(map['title']),
      confirmLabel: asString(map['confirmLabel']),
    );
  }

  final String message;
  final String? title;
  final String? confirmLabel;
}

/// One step an n8n workflow asks the app to perform, e.g.
/// `{"type": "set_alarm", "hour": 7, "minute": 30, "label": "Gym"}`.
///
/// Everything except `type` and `confirm` is kept in [params], unresolved:
/// string values may hold `{{key}}` templates that are filled from the app
/// state right before running.
class ActionSpec {
  const ActionSpec({required this.type, this.params = const {}, this.confirm});

  static ActionSpec? fromJson(Object? json) {
    final map = asMap(json);
    final type = asString(map['type'])?.trim();
    if (type == null || type.isEmpty) return null;
    return ActionSpec(
      type: type,
      params: Map<String, dynamic>.from(map)
        ..remove('type')
        ..remove('confirm'),
      confirm: ConfirmSpec.fromJson(map['confirm']),
    );
  }

  /// Parses a single action object or a list of them; invalid entries are
  /// skipped.
  static List<ActionSpec> listFrom(Object? json) {
    if (json == null) return const [];
    final items = json is List ? json : [json];
    return items.map(fromJson).whereType<ActionSpec>().toList();
  }

  /// Actions of a component: `action` (one) and/or `actions` (list).
  static List<ActionSpec> ofComponent(Map<String, dynamic> component) => [
    ...listFrom(component['action']),
    ...listFrom(component['actions']),
  ];

  final String type;
  final Map<String, dynamic> params;
  final ConfirmSpec? confirm;
}

/// Action types this version of the app understands.
const Set<String> supportedActionTypes = {
  // UI (need an open app screen)
  'submit',
  'navigate',
  'back',
  'reload',
  'set_state',
  // App
  'open_app',
  'toast',
  'dialog',
  // Device
  'notify',
  'set_alarm',
  'set_timer',
  'calendar_event',
  'open_url',
  'copy',
  'share',
  'dial',
  'sms',
  'email',
  'maps',
  'vibrate',
  'show_alarms',
  'open_settings',
  'launch_app',
  'read_clipboard',
  // Automations
  'schedule_alarm',
  'cancel_alarm',
  'report',
  'request_permission',
};

/// Actions that may run without the user looking (automations allowed per
/// app, and pushes received with the app closed): no UI, nothing opened.
const Set<String> automaticActionTypes = {
  'schedule_alarm',
  'cancel_alarm',
  'report',
  'notify',
};
