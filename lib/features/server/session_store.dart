import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/json.dart';
import '../../core/log.dart';
import 'n8n_api.dart';

/// Server session persisted between launches.
class StoredSession {
  const StoredSession({
    required this.baseUrl,
    required this.token,
    required this.expiresAt,
    required this.uid,
    required this.user,
    this.serverName,
  });

  factory StoredSession.fromJson(Map<String, dynamic> json) => StoredSession(
    baseUrl: Uri.parse(asString(json['baseUrl'])!),
    token: asString(json['token'])!,
    expiresAt: DateTime.parse(asString(json['expiresAt'])!),
    uid: asString(json['uid'])!,
    user: SessionUser.fromJson(asMap(json['user'])),
    serverName: asString(json['serverName']),
  );

  final Uri baseUrl;
  final String token;
  final DateTime expiresAt;

  /// Firebase uid the session was issued for.
  final String uid;
  final SessionUser user;
  final String? serverName;

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl.toString(),
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
    'uid': uid,
    'user': user.toJson(),
    'serverName': serverName,
  };
}

/// The session token lives in the Android Keystore-backed secure storage; the
/// last server URL (not secret) in shared preferences.
class SessionStore {
  SessionStore({FlutterSecureStorage? secure})
    : _secure =
          secure ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _secure;

  static const _sessionKey = 'nc.session';
  static const _deviceIdKey = 'nc.deviceId';

  /// Shared preferences key of the last server URL (also read on first run
  /// by OnboardingService to recognise existing installs).
  static const lastUrlKey = 'nc.serverUrl';

  Future<StoredSession?> read() async {
    try {
      final raw = await _secure.read(key: _sessionKey);
      if (raw == null) return null;
      return StoredSession.fromJson(asMap(jsonDecode(raw)));
    } catch (e) {
      // Corrupt or unreadable (e.g. restored backup): start over.
      appLog('SessionStore', 'discarding stored session: $e');
      await clear();
      return null;
    }
  }

  Future<void> write(StoredSession session) =>
      _secure.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  Future<void> clear() => _secure.delete(key: _sessionKey);

  Future<String?> readLastUrl() async =>
      (await SharedPreferences.getInstance()).getString(lastUrlKey);

  Future<void> writeLastUrl(String url) async =>
      (await SharedPreferences.getInstance()).setString(lastUrlKey, url);

  /// Random per-install id, sent to the server to tell devices apart.
  Future<String> deviceId() async {
    final existing = await _secure.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final id = base64Url.encode(bytes).replaceAll('=', '');
    await _secure.write(key: _deviceIdKey, value: id);
    return id;
  }
}
