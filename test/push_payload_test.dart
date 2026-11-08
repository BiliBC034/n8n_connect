import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/push/push_payload.dart';

void main() {
  final base = <String, dynamic>{
    'nc': '1',
    'id': 'abc',
    'title': 'T',
    'body': 'B',
    'actions': '[{"type":"set_alarm","hour":7}]',
    'app': 'alarm',
  };

  group('PushPayload.fromData', () {
    test('reads id, title, body, app and actions', () {
      final payload = PushPayload.fromData(base)!;
      expect(payload.id, 'abc');
      expect(payload.title, 'T');
      expect(payload.body, 'B');
      expect(payload.appId, 'alarm');
      expect(payload.actions, hasLength(1));
      expect(payload.actions.first.type, 'set_alarm');
    });

    test('returns null when nc is missing or not 1', () {
      expect(
        PushPayload.fromData(Map<String, dynamic>.from(base)..remove('nc')),
        isNull,
      );
      expect(PushPayload.fromData({...base, 'nc': '0'}), isNull);
    });

    test('invalid JSON in actions gives no raw actions', () {
      final payload = PushPayload.fromData({...base, 'actions': 'not json'})!;
      expect(payload.rawActions, isEmpty);
    });

    test('empty actions string gives no raw actions', () {
      final payload = PushPayload.fromData({...base, 'actions': ''})!;
      expect(payload.rawActions, isEmpty);
    });

    test('actions given as a list (not a string) work', () {
      final payload = PushPayload.fromData({
        ...base,
        'actions': [
          {'type': 'set_alarm', 'hour': 7},
        ],
      })!;
      expect(payload.actions, hasLength(1));
      expect(payload.actions.first.type, 'set_alarm');
    });

    test('a single map in actions counts as one action', () {
      final payload = PushPayload.fromData({
        ...base,
        'actions': {'type': 'toast'},
      })!;
      expect(payload.actions.single.type, 'toast');
    });

    test('empty app gives a null appId', () {
      expect(PushPayload.fromData({...base, 'app': ''})!.appId, isNull);
    });
  });

  group('PushPayload.encode and decode', () {
    test('round trip keeps id, title, body, appId and action types', () {
      final original = PushPayload.fromData(base)!;
      final decoded = PushPayload.decode(original.encode())!;
      expect(decoded.id, 'abc');
      expect(decoded.title, 'T');
      expect(decoded.body, 'B');
      expect(decoded.appId, 'alarm');
      expect(decoded.actions.map((a) => a.type).toList(), ['set_alarm']);
    });

    test('decode returns null for null, empty or invalid input', () {
      expect(PushPayload.decode(null), isNull);
      expect(PushPayload.decode(''), isNull);
      expect(PushPayload.decode('not json'), isNull);
    });
  });

  group('PushPayload.notificationId', () {
    test('is non-negative and equal for payloads with the same id', () {
      final first = PushPayload.fromData(base)!;
      final second = PushPayload.fromData({...base, 'title': 'Otro'})!;
      expect(first.notificationId, greaterThanOrEqualTo(0));
      expect(first.notificationId, second.notificationId);
    });
  });
}
