import 'dart:async';
import 'dart:convert';

import '../../core/app_config.dart';
import '../../core/json.dart';
import '../../core/log.dart';
import '../server/n8n_api.dart';
import '../server/server_session.dart';
import 'app_models.dart';
import 'apps_cache.dart';

/// A value from the server, or from the offline cache when the network
/// failed. [savedAt] is set only for cached values.
class CachedResult<T> {
  const CachedResult(this.value, {this.savedAt});

  final T value;
  final DateTime? savedAt;

  bool get fromCache => savedAt != null;
}

/// Apps published by the connected n8n server.
class AppsRepository {
  AppsRepository(this._session, {AppsCache? cache})
    : _offline = cache ?? AppsCache() {
    _session.addListener(_onSessionChanged);
  }

  final ServerSession _session;
  final AppsCache _offline;
  List<AppSummary>? _cache;
  Uri? _cacheServer;

  List<AppSummary>? get cached => _cache;

  /// Catalog from memory, the server, or the offline copy when the network
  /// is down.
  Future<CachedResult<List<AppSummary>>> list({bool refresh = false}) async {
    final memory = _cache;
    if (!refresh && memory != null) return CachedResult(memory);
    final server = _session.baseUrl;
    try {
      final json = await _session.request('GET', AppConfig.appsPath);
      final apps = _appsFrom(json);
      _cache = apps;
      _cacheServer = server;
      if (server != null) {
        await _saveIfStillConnected(
          server,
          (uri) => _offline.writeList(uri, jsonEncode(json)),
        );
      }
      return CachedResult(apps);
    } on N8nApiException catch (e) {
      if (!e.isNetwork || server == null) rethrow;
      final saved = await _readCached(
        () => _offline.readList(server),
        (json) => _appsFrom(json),
      );
      if (saved == null) rethrow;
      return saved;
    }
  }

  /// Looks the app up in the catalog, refreshing it once if needed (e.g. when
  /// opened from a push before the home screen loaded).
  Future<AppSummary> find(String id) async {
    for (final refresh in [false, true]) {
      final apps = (await list(refresh: refresh)).value;
      for (final app in apps) {
        if (app.id == id) return app;
      }
    }
    throw const N8nApiException('app_not_found');
  }

  /// The app's spec from the server, or its offline copy when the network is
  /// down.
  Future<CachedResult<AppSpec>> loadSpec(AppSummary app) async {
    final server = _session.baseUrl;
    try {
      final json = await _session.request('GET', app.path);
      final spec = AppSpec.fromJson(json);
      if (server != null) {
        await _saveIfStillConnected(
          server,
          (uri) => _offline.writeSpec(uri, app.id, jsonEncode(json)),
        );
      }
      return CachedResult(spec);
    } on N8nApiException catch (e) {
      if (!e.isNetwork || server == null) rethrow;
      final saved = await _readCached(
        () => _offline.readSpec(server, app.id),
        (json) => AppSpec.fromJson(json),
      );
      if (saved == null) rethrow;
      return saved;
    }
  }

  static const Set<String> _methods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};

  /// Sends app state to a workflow. GET puts it in the query string. Never
  /// answered from the offline cache.
  Future<ActionResponse> submit(
    String path,
    String method,
    Map<String, dynamic> payload,
  ) async {
    final verb = method.toUpperCase();
    if (!_methods.contains(verb)) {
      throw ArgumentError('submit: unsupported method $method');
    }
    final json = verb == 'GET'
        ? await _session.request(
            'GET',
            path,
            query: payload.map((k, v) => MapEntry(k, asString(v) ?? '')),
            timeout: AppConfig.submitTimeout,
          )
        : await _session.request(
            verb,
            path,
            body: payload,
            timeout: AppConfig.submitTimeout,
          );
    return ActionResponse.fromJson(json);
  }

  static List<AppSummary> _appsFrom(Map<String, dynamic> json) => asList(
    json['apps'],
  ).map(AppSummary.fromJson).whereType<AppSummary>().toList();

  /// Writes only while the same server is still connected, so a response that
  /// arrives after sign-out never repopulates the cleared cache.
  Future<void> _saveIfStillConnected(
    Uri server,
    Future<void> Function(Uri server) write,
  ) async {
    if (_session.baseUrl != server) return;
    await write(server);
  }

  /// Parses a saved copy. Null when there is none or it no longer parses.
  Future<CachedResult<T>?> _readCached<T>(
    Future<CacheEntry?> Function() read,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    final entry = await read();
    if (entry == null) return null;
    try {
      return CachedResult(
        parse(asMap(jsonDecode(entry.json))),
        savedAt: entry.savedAt,
      );
    } catch (e) {
      appLog('AppsRepository', 'ignoring unreadable cache: $e');
      return null;
    }
  }

  void _onSessionChanged() {
    if (!_session.isConnected) {
      _cache = null;
      _cacheServer = null;
      // Signed out or access revoked: no offline data stays on the device.
      unawaited(_offline.clearAll());
    } else if (_session.baseUrl != _cacheServer) {
      _cache = null;
      _cacheServer = null;
    }
  }
}
