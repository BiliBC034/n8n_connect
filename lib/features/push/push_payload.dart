import 'dart:convert';

import '../../core/json.dart';
import '../actions/action_spec.dart';

/// FCM data message sent by the "n8n Connect · Send to phone" workflow.
///
/// FCM data values are strings, so `actions` arrives JSON-encoded:
/// `{"nc": "1", "id": "…", "title": "…", "body": "…",
///   "actions": "[{\"type\":\"set_alarm\",\"hour\":7}]", "app": "alarm"}`
class PushPayload {
  const PushPayload({
    required this.id,
    required this.title,
    required this.body,
    this.rawActions = const [],
    this.appId,
    this.recipient,
  });

  /// Returns null for messages that are not n8n Connect commands.
  static PushPayload? fromData(Map<String, dynamic> data) {
    if (asString(data['nc']) != '1') return null;

    var raw = data['actions'];
    if (raw is String) {
      try {
        raw = raw.trim().isEmpty ? const [] : jsonDecode(raw);
      } on FormatException {
        raw = const [];
      }
    }
    final rawActions = raw is List ? raw : (raw is Map ? [raw] : const []);
    final title = asString(data['title']) ?? '';
    final body = asString(data['body']) ?? '';
    final app = asString(data['app']);
    final to = asString(data['to'])?.trim().toLowerCase();
    return PushPayload(
      id: asString(data['id']) ?? '${title.hashCode}-${body.hashCode}',
      title: title,
      body: body,
      rawActions: rawActions,
      appId: app == null || app.isEmpty ? null : app,
      recipient: to == null || to.isEmpty ? null : to,
    );
  }

  /// Inverse of [encode]; used for the local notification payload.
  static PushPayload? decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return fromData(asMap(jsonDecode(encoded)));
    } on FormatException {
      return null;
    }
  }

  final String id;
  final String title;
  final String body;
  final List<dynamic> rawActions;
  final String? appId;

  /// Email of the account the push is for (`to`), when the server sends it.
  final String? recipient;

  List<ActionSpec> get actions => ActionSpec.listFrom(rawActions);

  /// Stable notification id derived from the message id.
  int get notificationId => id.hashCode & 0x7fffffff;

  String encode() => jsonEncode({
    'nc': '1',
    'id': id,
    'title': title,
    'body': body,
    'actions': rawActions,
    'app': appId ?? '',
    'to': recipient ?? '',
  });
}
