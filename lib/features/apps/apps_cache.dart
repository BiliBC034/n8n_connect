import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/json.dart';
import '../../core/log.dart';

/// Raw JSON saved for offline use, with the time it was saved.
class CacheEntry {
  const CacheEntry({required this.json, required this.savedAt});

  final String json;
  final DateTime savedAt;
}

/// Offline copy of the apps catalog and of each app spec, per server URL.
///
/// Every key starts with [prefix] so [clearAll] removes exactly what this
/// class wrote and nothing else in SharedPreferences.
class AppsCache {
  AppsCache({SharedPreferences? prefs}) : _prefs = prefs;

  static const String prefix = 'nc.cache.';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  static String _listKey(Uri server) => '${prefix}apps|$server';

  static String _specKey(Uri server, String appId) =>
      '${prefix}spec|$server|${Uri.encodeComponent(appId)}';

  Future<void> writeList(Uri server, String json) =>
      _write(_listKey(server), json);

  Future<CacheEntry?> readList(Uri server) => _read(_listKey(server));

  Future<void> writeSpec(Uri server, String appId, String json) =>
      _write(_specKey(server, appId), json);

  Future<CacheEntry?> readSpec(Uri server, String appId) =>
      _read(_specKey(server, appId));

  /// Removes every entry written by this class. Used on sign-out.
  Future<void> clearAll() async {
    try {
      final prefs = await _store;
      final keys = prefs.getKeys().where((key) => key.startsWith(prefix));
      for (final key in keys.toList()) {
        await prefs.remove(key);
      }
    } catch (e) {
      appLog('AppsCache', 'clear failed: $e');
    }
  }

  Future<void> _write(String key, String json) async {
    try {
      final prefs = await _store;
      await prefs.setString(
        key,
        jsonEncode({'savedAt': DateTime.now().toIso8601String(), 'json': json}),
      );
    } catch (e) {
      appLog('AppsCache', 'write failed: $e');
    }
  }

  Future<CacheEntry?> _read(String key) async {
    try {
      final raw = (await _store).getString(key);
      if (raw == null) return null;
      final map = asMap(jsonDecode(raw));
      final json = asString(map['json']);
      final savedAt = DateTime.tryParse(asString(map['savedAt']) ?? '');
      if (json == null || savedAt == null) return null;
      return CacheEntry(json: json, savedAt: savedAt);
    } catch (e) {
      appLog('AppsCache', 'read failed: $e');
      return null;
    }
  }
}

/// Short local time for "Updated" and offline notices: `HH:mm` when [time] is
/// today, `dd/MM HH:mm` otherwise.
String formatSavedTime(DateTime time, {DateTime? now}) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = time.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final hm = '${two(local.hour)}:${two(local.minute)}';
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  return sameDay ? hm : '${two(local.day)}/${two(local.month)} $hm';
}
