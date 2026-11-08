import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/app_config.dart';
import '../../core/json.dart';
import 'server_url.dart';

/// Error returned by an n8n Connect server, or a transport failure.
///
/// `code` is either one sent by the server in `{"error": {"code": ...}}`
/// (`not_allowed`, `email_not_verified`, ...) or one of the client codes:
/// `network`, `timeout`, `session_invalid`, `not_found`, `bad_response`,
/// `not_n8n_connect`, `unsupported_protocol`, `wrong_firebase_project`,
/// `not_connected`, `signed_out`, `http_<status>`.
class N8nApiException implements Exception {
  const N8nApiException(this.code, {this.status, this.message});

  final String code;
  final int? status;
  final String? message;

  /// The session JWT was rejected (n8n's JWT Auth answers 401 "No token
  /// provided" or 403 "jwt expired" / "invalid signature" as plain text).
  bool get isSessionInvalid => code == 'session_invalid';

  bool get isNetwork => code == 'network' || code == 'timeout';

  /// The server no longer accepts this account: the local session must go.
  bool get isAccessRevoked => const {
    'not_allowed',
    'email_not_verified',
    'account_disabled',
    'no_email',
  }.contains(code);

  @override
  String toString() => 'N8nApiException($code, status: $status, $message)';
}

class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.protocol,
    this.firebaseProjectId,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
    name: asString(json['name']) ?? 'n8n',
    protocol: asInt(json['protocol']) ?? 1,
    firebaseProjectId: asString(json['firebaseProjectId']),
  );

  final String name;
  final int protocol;
  final String? firebaseProjectId;
}

class SessionUser {
  const SessionUser({required this.email, this.name = '', this.role = 'user'});

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    email: asString(json['email']) ?? '',
    name: asString(json['name']) ?? '',
    role: asString(json['role']) ?? 'user',
  );

  final String email;
  final String name;
  final String role;

  Map<String, dynamic> toJson() => {'email': email, 'name': name, 'role': role};
}

class SessionGrant {
  const SessionGrant({
    required this.token,
    required this.expiresAt,
    required this.user,
    this.serverName,
  });

  final String token;
  final DateTime expiresAt;
  final SessionUser user;
  final String? serverName;
}

/// Stateless HTTP client for the n8n Connect webhooks.
class N8nApi {
  N8nApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ServerInfo> fetchInfo(Uri base) async {
    final json = await send('GET', webhookUri(base, AppConfig.infoPath));
    if (json['service'] != 'n8n-connect') {
      throw const N8nApiException('not_n8n_connect');
    }
    return ServerInfo.fromJson(json);
  }

  /// Trades a Firebase ID token for a server session (see the Core workflow).
  Future<SessionGrant> exchange(
    Uri base, {
    required String idToken,
    required Map<String, dynamic> device,
  }) async {
    final json = await send(
      'POST',
      webhookUri(base, AppConfig.authPath),
      bearer: idToken,
      body: {'device': device},
    );
    final token = asString(json['token']);
    final expiresAt = DateTime.tryParse(asString(json['expiresAt']) ?? '');
    if (token == null || token.isEmpty || expiresAt == null) {
      throw const N8nApiException('bad_response');
    }
    return SessionGrant(
      token: token,
      expiresAt: expiresAt,
      user: SessionUser.fromJson(asMap(json['user'])),
      serverName: asString(asMap(json['server'])['name']),
    );
  }

  /// Tells the server to forget this device's push token.
  Future<void> logout(Uri base, String token) async {
    await send(
      'POST',
      webhookUri(base, AppConfig.logoutPath),
      bearer: token,
      body: const <String, dynamic>{},
      timeout: const Duration(seconds: 6),
    );
  }

  Future<Map<String, dynamic>> send(
    String method,
    Uri uri, {
    String? bearer,
    Object? body,
    Duration? timeout,
  }) async {
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(timeout ?? AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const N8nApiException('timeout');
    } on SocketException catch (e) {
      throw N8nApiException('network', message: e.message);
    } on HandshakeException catch (e) {
      throw N8nApiException('network', message: e.message);
    } on http.ClientException catch (e) {
      throw N8nApiException('network', message: e.message);
    }
    return decodeResponse(response.statusCode, response.bodyBytes);
  }
}

/// Maps an HTTP response to JSON or an [N8nApiException]. Public for tests.
Map<String, dynamic> decodeResponse(int status, List<int> bodyBytes) {
  final text = utf8.decode(bodyBytes, allowMalformed: true).trim();
  Object? body;
  if (text.isNotEmpty) {
    try {
      body = jsonDecode(text);
    } on FormatException {
      body = null;
    }
  }

  if (status >= 200 && status < 300) {
    if (body is Map) return asMap(body);
    if (text.isEmpty) return <String, dynamic>{};
    if (body is List) return {'data': body};
    throw N8nApiException('bad_response', status: status);
  }

  String? code;
  String? message;
  if (body is Map) {
    final error = body['error'];
    if (error is Map) {
      code = asString(error['code']);
      message = asString(error['message']);
    } else if (error is String) {
      message = error;
    }
    message ??= asString(body['message']);
  } else if (text.isNotEmpty) {
    message = text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }

  if (code == null) {
    if (status == 401 || (status == 403 && body is! Map)) {
      code = 'session_invalid';
    } else if (status == 404) {
      code = 'not_found';
    } else {
      code = 'http_$status';
    }
  }
  throw N8nApiException(code, status: status, message: message);
}
