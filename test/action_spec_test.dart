import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/actions/action_spec.dart';

void main() {
  group('ActionSpec.fromJson', () {
    test('reads the type and keeps the other fields as params', () {
      final spec = ActionSpec.fromJson({
        'type': 'set_alarm',
        'hour': 7,
        'minute': 30,
        'label': 'Gym',
        'confirm': 'Sure?',
      })!;
      expect(spec.type, 'set_alarm');
      expect(spec.params, {'hour': 7, 'minute': 30, 'label': 'Gym'});
      expect(spec.confirm?.message, 'Sure?');
    });

    test('parses a confirm map', () {
      final spec = ActionSpec.fromJson({
        'type': 'submit',
        'confirm': {'title': 'T', 'message': 'M', 'confirmLabel': 'OK'},
      })!;
      expect(spec.confirm?.title, 'T');
      expect(spec.confirm?.message, 'M');
      expect(spec.confirm?.confirmLabel, 'OK');
    });

    test('a confirm map without message gives no confirm', () {
      final spec = ActionSpec.fromJson({
        'type': 'submit',
        'confirm': {'title': 'T'},
      })!;
      expect(spec.confirm, isNull);
    });

    test('returns null without a usable type', () {
      expect(ActionSpec.fromJson({}), isNull);
      expect(ActionSpec.fromJson({'type': ''}), isNull);
      expect(ActionSpec.fromJson('x'), isNull);
    });
  });

  group('ActionSpec.listFrom', () {
    test('null gives an empty list', () {
      expect(ActionSpec.listFrom(null), isEmpty);
    });

    test('a single map gives one action', () {
      expect(ActionSpec.listFrom({'type': 'toast'}), hasLength(1));
    });

    test('skips invalid entries and keeps the order', () {
      final types = ActionSpec.listFrom([
        {'type': 'toast'},
        {'no': 'type'},
        {'type': 'copy'},
      ]).map((a) => a.type).toList();
      expect(types, ['toast', 'copy']);
    });
  });

  group('ActionSpec.ofComponent', () {
    test('returns action first, then actions in order', () {
      final component = <String, dynamic>{
        'action': {'type': 'back'},
        'actions': [
          {'type': 'toast'},
          {'type': 'copy'},
        ],
      };
      final types = ActionSpec.ofComponent(
        component,
      ).map((a) => a.type).toList();
      expect(types, ['back', 'toast', 'copy']);
    });
  });

  group('supportedActionTypes', () {
    test('includes the core action types', () {
      expect(
        supportedActionTypes,
        containsAll(['set_alarm', 'submit', 'open_url']),
      );
    });
  });
}
