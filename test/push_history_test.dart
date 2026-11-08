import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/push/push_history.dart';
import 'package:n8n_connect/features/push/push_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';

PushPayload _payload(String id, {String title = 'T'}) => PushPayload(
  id: id,
  title: title,
  body: 'B$id',
  rawActions: const [
    {'type': 'set_alarm', 'hour': 7, 'minute': 30},
  ],
  appId: 'alarm',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'record and reload from a new instance keeps entries and statuses',
    () async {
      final first = PushHistory();
      await first.record(_payload('a'), PushStatus.pending);
      await first.record(_payload('b'), PushStatus.executed);
      await first.record(_payload('c'), PushStatus.failed);

      final reloaded = PushHistory();
      await reloaded.load();
      final entries = reloaded.entries;

      expect(entries.map((e) => e.payload.id), ['c', 'b', 'a']);
      expect(entries.map((e) => e.status), [
        PushStatus.failed,
        PushStatus.executed,
        PushStatus.pending,
      ]);
      expect(entries.first.payload.title, 'T');
      expect(entries.first.payload.body, 'Bc');
      expect(entries.first.payload.appId, 'alarm');
      expect(entries.first.payload.actions.single.type, 'set_alarm');
      expect(entries.first.receivedAt, first.entries.first.receivedAt);
    },
  );

  test(
    'same id updates status without duplicating and keeps receivedAt',
    () async {
      final history = PushHistory();
      await history.record(_payload('a'), PushStatus.pending);
      await history.record(_payload('b'), PushStatus.pending);
      final originalAt = history.entries.last.receivedAt;

      await history.record(_payload('a'), PushStatus.executed);

      expect(history.entries, hasLength(2));
      expect(history.entries.last.payload.id, 'a');
      expect(history.entries.last.status, PushStatus.executed);
      expect(history.entries.last.receivedAt, originalAt);

      final reloaded = PushHistory();
      await reloaded.load();
      expect(reloaded.entries, hasLength(2));
      expect(reloaded.entries.last.status, PushStatus.executed);
      expect(reloaded.entries.last.receivedAt, originalAt);
    },
  );

  test('keeps only the 50 newest entries', () async {
    final history = PushHistory();
    for (var i = 0; i < 55; i++) {
      await history.record(_payload('$i'), PushStatus.executed);
    }

    expect(history.entries, hasLength(50));
    expect(history.entries.first.payload.id, '54');
    expect(history.entries.last.payload.id, '5');

    final reloaded = PushHistory();
    await reloaded.load();
    expect(reloaded.entries, hasLength(50));
    expect(reloaded.entries.first.payload.id, '54');
    expect(reloaded.entries.last.payload.id, '5');
  });

  test('clear empties the history and the stored data', () async {
    final history = PushHistory();
    await history.record(_payload('a'), PushStatus.pending);
    await history.clear();

    expect(history.entries, isEmpty);

    final reloaded = PushHistory();
    await reloaded.load();
    expect(reloaded.entries, isEmpty);
  });

  test('entries cannot be modified from outside', () async {
    final history = PushHistory();
    await history.record(_payload('a'), PushStatus.pending);
    expect(
      () => history.entries.add(
        PushHistoryEntry(
          payload: _payload('x'),
          receivedAt: DateTime.now(),
          status: PushStatus.pending,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('corrupt stored JSON starts with an empty history', () async {
    SharedPreferences.setMockInitialValues({
      'nc.push.history': '{not valid json',
    });
    final history = PushHistory();
    await history.load();
    expect(history.entries, isEmpty);

    // A new record still works and replaces the corrupt data.
    await history.record(_payload('a'), PushStatus.pending);
    expect(history.entries, hasLength(1));
  });

  test('invalid entries are skipped, valid ones kept', () async {
    final valid = PushHistoryEntry(
      payload: _payload('ok'),
      receivedAt: DateTime(2026, 3, 4, 10, 30),
      status: PushStatus.ignored,
    );
    SharedPreferences.setMockInitialValues({
      'nc.push.history': jsonEncode([
        42,
        {'payload': 'x', 'status': 'pending'},
        {
          'payload': valid.payload.encode(),
          'receivedAt': valid.receivedAt.toIso8601String(),
          'status': 'ignored',
        },
      ]),
    });
    final history = PushHistory();
    await history.load();

    expect(history.entries, hasLength(1));
    expect(history.entries.single.payload.id, 'ok');
    expect(history.entries.single.status, PushStatus.ignored);
    expect(history.entries.single.receivedAt, valid.receivedAt);
  });
}
