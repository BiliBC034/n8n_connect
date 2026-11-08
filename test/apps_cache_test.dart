import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/apps/apps_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final serverA = Uri.parse('https://a.example.com');
  final serverB = Uri.parse('https://b.example.com');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppsCache', () {
    test('writes and reads the apps list per server', () async {
      final cache = AppsCache();
      await cache.writeList(serverA, '{"apps":[]}');
      final entry = await cache.readList(serverA);
      expect(entry, isNotNull);
      expect(entry!.json, '{"apps":[]}');
      expect(await cache.readList(serverB), isNull);
    });

    test('writes and reads a spec per server and app id', () async {
      final cache = AppsCache();
      await cache.writeSpec(serverA, 'alarm', '{"screens":[]}');
      expect((await cache.readSpec(serverA, 'alarm'))!.json, '{"screens":[]}');
      expect(await cache.readSpec(serverA, 'gym'), isNull);
      expect(await cache.readSpec(serverB, 'alarm'), isNull);
    });

    test('keeps two servers isolated', () async {
      final cache = AppsCache();
      await cache.writeList(serverA, 'A');
      await cache.writeList(serverB, 'B');
      await cache.writeSpec(serverA, 'x', 'SA');
      await cache.writeSpec(serverB, 'x', 'SB');
      expect((await cache.readList(serverA))!.json, 'A');
      expect((await cache.readList(serverB))!.json, 'B');
      expect((await cache.readSpec(serverA, 'x'))!.json, 'SA');
      expect((await cache.readSpec(serverB, 'x'))!.json, 'SB');
    });

    test('records when the entry was saved', () async {
      final cache = AppsCache();
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await cache.writeList(serverA, '{}');
      final after = DateTime.now().add(const Duration(seconds: 1));
      final savedAt = (await cache.readList(serverA))!.savedAt;
      expect(savedAt.isAfter(before), isTrue);
      expect(savedAt.isBefore(after), isTrue);
    });

    test('clearAll removes what it wrote and keeps unrelated keys', () async {
      SharedPreferences.setMockInitialValues({'nc.serverUrl': 'https://a'});
      final cache = AppsCache();
      await cache.writeList(serverA, '{}');
      await cache.writeSpec(serverB, 'alarm', '{}');

      await cache.clearAll();

      expect(await cache.readList(serverA), isNull);
      expect(await cache.readSpec(serverB, 'alarm'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('nc.serverUrl'), 'https://a');
      expect(
        prefs.getKeys().where((k) => k.startsWith(AppsCache.prefix)),
        isEmpty,
      );
    });
  });

  group('formatSavedTime', () {
    test('shows only the time for the same day', () {
      final now = DateTime(2026, 11, 2, 18, 0);
      expect(formatSavedTime(DateTime(2026, 11, 2, 9, 5), now: now), '09:05');
    });

    test('adds the date for another day', () {
      final now = DateTime(2026, 11, 2, 18, 0);
      expect(
        formatSavedTime(DateTime(2026, 10, 30, 21, 45), now: now),
        '30/10 21:45',
      );
    });
  });
}
