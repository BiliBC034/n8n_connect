import 'package:shared_preferences/shared_preferences.dart';

/// Per-app permission for n8n to run actions on this phone without asking
/// (pushes in the background included). Granted by the user from the app's
/// own screen (`automation` component) and revocable in Settings.
///
/// Uses SharedPreferencesAsync (no cache) so the FCM background isolate sees
/// changes made by the UI isolate.
class AutomationConsent {
  AutomationConsent._();

  static const String _prefix = 'nc.auto.';

  static String _key(Uri server, String appId) =>
      '$_prefix${server.host}:${server.port}${server.path}|$appId';

  static Future<bool> isAllowed(Uri server, String appId) async =>
      await SharedPreferencesAsync().getBool(_key(server, appId)) ?? false;

  static Future<void> setAllowed(Uri server, String appId, bool allowed) async {
    final prefs = SharedPreferencesAsync();
    if (allowed) {
      await prefs.setBool(_key(server, appId), true);
    } else {
      await prefs.remove(_key(server, appId));
    }
  }

  /// App ids with automation allowed on [server].
  static Future<List<String>> allowedApps(Uri server) async {
    final prefix = _key(server, '');
    final keys = await SharedPreferencesAsync().getKeys();
    return keys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList()
      ..sort();
  }

  /// Revokes everything (sign-out / disconnect).
  static Future<void> clearAll() async {
    final prefs = SharedPreferencesAsync();
    final keys = await prefs.getKeys();
    for (final key in keys.where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}
