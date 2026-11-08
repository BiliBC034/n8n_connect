import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/alarms/alarm_engine.dart';

/// Random lowercase id without '/', which is the separator the engine hashes.
String _text(Random random) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789-_';
  final length = 1 + random.nextInt(8);
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

void main() {
  group('AlarmEngine.nativeId', () {
    test('is stable for the same inputs', () {
      expect(
        AlarmEngine.nativeId('hola', 'a1'),
        AlarmEngine.nativeId('hola', 'a1'),
      );
      expect(AlarmEngine.nativeId('', ''), AlarmEngine.nativeId('', ''));
    });

    test('matches the reference FNV-1a value (alarms rely on it)', () {
      // Changing the hash makes existing alarms impossible to replace or
      // cancel, so this value must not change.
      expect(AlarmEngine.nativeId('hola', 'a1'), 653669632);
    });

    test('is positive, non-zero and fits in 31 bits', () {
      final random = Random(7);
      for (var i = 0; i < 1000; i++) {
        final id = AlarmEngine.nativeId(_text(random), _text(random));
        expect(id, greaterThan(0));
        expect(id, lessThanOrEqualTo(0x7fffffff));
      }
    });

    test('differs for different app/id pairs (200 combinations)', () {
      final random = Random(42);
      final pairs = <String>{};
      final ids = <int>{};
      while (pairs.length < 200) {
        final app = _text(random);
        final id = _text(random);
        if (!pairs.add('$app\u0000$id')) continue;
        ids.add(AlarmEngine.nativeId(app, id));
      }
      expect(ids.length, 200);
    });

    test('differs when the joined text differs', () {
      // The engine hashes '${appId.length}:$appId/$id', so a '/' inside an id
      // cannot make two different pairs collide.
      expect(
        AlarmEngine.nativeId('a/b', 'c'),
        isNot(AlarmEngine.nativeId('a', 'b/c')),
      );
      expect(
        AlarmEngine.nativeId('a', 'b'),
        isNot(AlarmEngine.nativeId('a/b', '')),
      );
      expect(
        AlarmEngine.nativeId('ab', 'c'),
        isNot(AlarmEngine.nativeId('a', 'bc')),
      );
      expect(
        AlarmEngine.nativeId('a', 'b'),
        isNot(AlarmEngine.nativeId('a', 'c')),
      );
    });
  });
}
