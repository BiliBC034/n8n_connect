import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_config.dart';
import '../../core/log.dart';
import '../auth/auth_service.dart';
import 'device_identity.dart';
import 'n8n_api.dart';
import 'server_url.dart';
import 'session_store.dart';

/// Link between the signed-in Firebase account and one n8n server.
///
/// Flow: the app sends its Firebase ID token to `n8n-connect/auth`; the server
/// verifies it with Google, checks its allow list and returns a short-lived
/// JWT that every other webhook validates with n8n's built-in JWT Auth. The
/// JWT is renewed transparently with a fresh Firebase ID token.
class ServerSession extends ChangeNotifier {
  ServerSession({
    required N8nApi api,
    required SessionStore store,
    required AuthService auth,
    required Future<String?> Function() pushToken,
    Future<void> Function()? onSessionClosed,
  }) : _api = api,
       _store = store,
       _auth = auth,
       _pushToken = pushToken,
       _onSessionClosed = onSessionClosed {
    _auth.addListener(_onAuthChanged);
  }

  final N8nApi _api;
  final SessionStore _store;
  final AuthService _auth;
  final Future<String?> Function() _pushToken;

  /// Runs when the session ends for good (disconnect, sign-out, account
  /// change, access revoked): the app deletes its FCM token there, so pushes
  /// for that account stop even if the server could not be told.
  final Future<void> Function()? _onSessionClosed;

  StoredSession? _session;
  DeviceIdentity? _device;
  String? _lastUrl;
  Future<void>? _refreshing;
  N8nApiException? _lastError;

  /// Bumped whenever the session is replaced or closed, so an exchange that
  /// was already in flight cannot bring back a session the user just ended.
  int _generation = 0;

  bool get isConnected => _session != null;
  Uri? get baseUrl => _session?.baseUrl;
  String? get serverName => _session?.serverName;
  SessionUser? get user => _session?.user;
  DateTime? get expiresAt => _session?.expiresAt;
  DeviceIdentity? get device => _device;

  /// Last server URL used, to prefill the connect screen.
  String? get lastUrl => _session?.baseUrl.toString() ?? _lastUrl;

  /// Why the session was dropped (e.g. the account was removed from the
  /// server's allow list). Shown on the connect screen.
  N8nApiException? get lastError => _lastError;

  Future<void> restore() async {
    _device = await DeviceIdentity.load(_store);
    _lastUrl = await _store.readLastUrl();
    final stored = await _store.read();
    final uid = _auth.currentUser?.uid;
    if (stored != null && uid != null && stored.uid == uid) {
      _session = stored;
    } else if (stored != null) {
      await _store.clear();
    }
    notifyListeners();
  }

  /// Validates the server (`n8n-connect/info`) and opens a session on it.
  Future<ServerInfo> connect(String rawUrl) async {
    final base = normalizeServerUrl(rawUrl);
    final info = await _api.fetchInfo(base);
    if (info.protocol > AppConfig.protocolVersion) {
      throw const N8nApiException('unsupported_protocol');
    }
    final projectId = Firebase.app().options.projectId;
    if (info.firebaseProjectId != projectId) {
      throw const N8nApiException('wrong_firebase_project');
    }

    final generation = ++_generation;
    final previous = _session;
    final next = await _exchange(base, serverName: info.name);
    if (generation != _generation) {
      throw const N8nApiException('not_connected');
    }
    await _commit(next);
    // Switching servers: release the old one only once the new one works.
    if (previous != null && previous.baseUrl != base) {
      _logoutQuietly(previous);
    }
    _lastUrl = base.toString();
    await _store.writeLastUrl(_lastUrl!);
    _lastError = null;
    notifyListeners();
    return info;
  }

  /// Renews the session JWT (also re-registers the push token).
  Future<void> refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final session = _session;
    if (session == null) {
      return Future.error(const N8nApiException('not_connected'));
    }
    final generation = _generation;
    final future = () async {
      try {
        final next = await _exchange(
          session.baseUrl,
          serverName: session.serverName,
        );
        // Disconnected, signed out or switched server meanwhile: drop it.
        if (generation != _generation) {
          throw const N8nApiException('not_connected');
        }
        await _commit(next);
        notifyListeners();
      } on N8nApiException catch (e) {
        if (e.isAccessRevoked && generation == _generation) await _drop(e);
        rethrow;
      }
    }();
    _refreshing = future.whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  /// Authenticated call to a webhook of the connected server. Renews the
  /// session first when it is about to expire, and once more if the server
  /// rejects it.
  Future<Map<String, dynamic>> request(
    String method,
    String pathOrUrl, {
    Object? body,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final session = _session;
    if (session == null) throw const N8nApiException('not_connected');
    final uri = webhookUri(session.baseUrl, pathOrUrl, query: query);

    final refreshAt = session.expiresAt.subtract(
      AppConfig.sessionRefreshMargin,
    );
    if (DateTime.now().isAfter(refreshAt)) await refresh();

    // Never send a token issued by another server to this URI.
    String tokenFor() {
      final current = _session;
      if (current == null || current.baseUrl != session.baseUrl) {
        throw const N8nApiException('not_connected');
      }
      return current.token;
    }

    Future<Map<String, dynamic>> send() => _api.send(
      method,
      uri,
      bearer: tokenFor(),
      body: body,
      timeout: timeout,
    );

    try {
      return await send();
    } on N8nApiException catch (e) {
      if (!e.isSessionInvalid) rethrow;
      await refresh();
      return send();
    }
  }

  /// Forgets the session locally and asks the server to stop sending pushes
  /// to this device. Keeps the server URL for next time.
  Future<void> disconnect() async {
    final session = _session;
    if (session == null) return;
    _generation++;
    _session = null;
    await _store.clear();
    notifyListeners();
    _logoutQuietly(session);
    _closed();
  }

  /// FCM rotated the device token: re-register it with the server.
  Future<void> onPushTokenChanged() async {
    if (!isConnected) return;
    try {
      await refresh();
    } catch (e) {
      appLog('Session', 'could not re-register push token: $e');
    }
  }

  void _logoutQuietly(StoredSession session) {
    unawaited(
      _api.logout(session.baseUrl, session.token).catchError((Object e) {
        appLog('Session', 'logout call failed: $e');
      }),
    );
  }

  void _closed() {
    final callback = _onSessionClosed;
    if (callback == null) return;
    unawaited(
      callback().catchError((Object e) {
        appLog('Session', 'session close hook failed: $e');
      }),
    );
  }

  Future<void> _commit(StoredSession next) async {
    _session = next;
    await _store.write(next);
  }

  /// Trades a Firebase ID token for a session. Does not change [_session]:
  /// callers commit the result only if nothing else happened meanwhile.
  Future<StoredSession> _exchange(Uri base, {String? serverName}) async {
    final user = _auth.currentUser;
    if (user == null) throw const N8nApiException('signed_out');
    final device = _device ??= await DeviceIdentity.load(_store);

    String? pushToken;
    try {
      pushToken = await _pushToken();
    } catch (e) {
      appLog('Session', 'no push token: $e');
    }

    Future<SessionGrant> attempt({required bool forceRefresh}) async {
      final String? idToken;
      try {
        idToken = await user.getIdToken(forceRefresh);
      } on FirebaseAuthException catch (e) {
        // Offline: let callers fall back to their saved data.
        if (e.code == 'network-request-failed') {
          throw N8nApiException('network', message: e.message);
        }
        throw N8nApiException('signed_out', message: e.message);
      }
      if (idToken == null) throw const N8nApiException('signed_out');
      return _api.exchange(
        base,
        idToken: idToken,
        device: device.toJson(fcmToken: pushToken),
      );
    }

    SessionGrant grant;
    try {
      grant = await attempt(forceRefresh: false);
    } on N8nApiException catch (e) {
      // A cached ID token can be stale (e.g. email verified after it was
      // minted): retry once with a fresh one.
      if (e.code != 'invalid_token' && e.code != 'email_not_verified') rethrow;
      grant = await attempt(forceRefresh: true);
    }

    return StoredSession(
      baseUrl: base,
      token: grant.token,
      expiresAt: grant.expiresAt,
      uid: user.uid,
      user: grant.user,
      serverName: grant.serverName ?? serverName,
    );
  }

  Future<void> _drop(N8nApiException reason) async {
    _generation++;
    _lastError = reason;
    _session = null;
    await _store.clear();
    notifyListeners();
    _closed();
  }

  void _onAuthChanged() {
    final session = _session;
    if (session == null) return;
    final User? user = _auth.currentUser;
    if (user == null || user.uid != session.uid) {
      _generation++;
      _session = null;
      unawaited(_store.clear());
      notifyListeners();
      // The session JWT is still valid: stop pushes to this device.
      _logoutQuietly(session);
      _closed();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
