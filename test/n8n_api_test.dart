import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:n8n_connect/features/server/n8n_api.dart';

void main() {
  group('decodeResponse', () {
    Map<String, dynamic> decode(int status, String body) =>
        decodeResponse(status, utf8.encode(body));

    test('returns a JSON object on 2xx', () {
      expect(decode(200, '{"a":1}'), {'a': 1});
    });

    test('returns an empty map for an empty 2xx body', () {
      expect(decode(200, ''), <String, dynamic>{});
      expect(decode(204, ''), <String, dynamic>{});
    });

    test('wraps a JSON array under data', () {
      expect(decode(200, '[1,2]'), {
        'data': [1, 2],
      });
    });

    test('throws bad_response for a non-JSON 2xx body', () {
      expect(() => decode(200, 'hello'), throwsA(_apiError('bad_response')));
    });

    test('maps a server error object to its code, status and message', () {
      const body =
          '{"error":{"code":"not_allowed","message":"Account x is not allowed"}}';
      final error = _catchApiError(() => decode(403, body));
      expect(error.code, 'not_allowed');
      expect(error.status, 403);
      expect(error.message, 'Account x is not allowed');
      expect(error.isAccessRevoked, isTrue);
    });

    test('treats plain-text 401 and 403 from JWT auth as session_invalid', () {
      for (final entry in {
        401: 'No token provided',
        403: 'jwt expired',
      }.entries) {
        final error = _catchApiError(() => decode(entry.key, entry.value));
        expect(error.code, 'session_invalid', reason: entry.value);
        expect(error.isSessionInvalid, isTrue, reason: entry.value);
      }
    });

    test('maps a 404 with a message to not_found', () {
      final error = _catchApiError(
        () => decode(
          404,
          '{"code":404,"message":"The requested webhook is not registered."}',
        ),
      );
      expect(error.code, 'not_found');
      expect(error.message, 'The requested webhook is not registered.');
    });

    test('keeps a custom server error code', () {
      expect(
        () => decode(424, '{"error":{"code":"push_failed","message":"x"}}'),
        throwsA(_apiError('push_failed')),
      );
    });

    test('falls back to http_<status> for other plain-text errors', () {
      expect(() => decode(500, 'boom'), throwsA(_apiError('http_500')));
    });

    test('decodes UTF-8 characters in successful bodies', () {
      expect(decode(200, '{"m":"Sí ñ"}')['m'], 'Sí ñ');
    });
  });

  group('N8nApi.fetchInfo', () {
    test('requests the info webhook and parses the server info', () async {
      late http.Request seen;
      final api = N8nApi(
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            '{"service":"n8n-connect","protocol":1,"name":"Test",'
            '"firebaseProjectId":"p"}',
            200,
          );
        }),
      );

      final info = await api.fetchInfo(Uri.parse('https://example.com'));

      expect(seen.method, 'GET');
      expect(
        seen.url.toString(),
        'https://example.com/webhook/n8n-connect/info',
      );
      expect(info.name, 'Test');
      expect(info.protocol, 1);
      expect(info.firebaseProjectId, 'p');
    });

    test('rejects a server that does not identify as n8n Connect', () async {
      final api = N8nApi(
        client: MockClient(
          (_) async => http.Response('{"service":"other"}', 200),
        ),
      );

      expect(
        () => api.fetchInfo(Uri.parse('https://example.com')),
        throwsA(_apiError('not_n8n_connect')),
      );
    });
  });

  group('N8nApi.exchange', () {
    test('posts the device with the Firebase ID token as bearer', () async {
      late http.Request seen;
      final api = N8nApi(
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            '{"token":"t","expiresAt":"2030-01-01T00:00:00.000Z",'
            '"user":{"email":"a@b.c","role":"admin"},"server":{"name":"S"}}',
            200,
          );
        }),
      );

      final grant = await api.exchange(
        Uri.parse('https://example.com'),
        idToken: 'idtok',
        device: {'id': 'dev123'},
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/webhook/n8n-connect/auth');
      expect(seen.headers['Authorization'], 'Bearer idtok');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect((body['device'] as Map)['id'], 'dev123');

      expect(grant.token, 't');
      expect(grant.expiresAt.year, 2030);
      expect(grant.user.email, 'a@b.c');
      expect(grant.user.role, 'admin');
      expect(grant.serverName, 'S');
    });

    test('throws bad_response when the token is missing', () async {
      final api = N8nApi(
        client: MockClient(
          (_) async =>
              http.Response('{"expiresAt":"2030-01-01T00:00:00.000Z"}', 200),
        ),
      );

      expect(
        () => api.exchange(
          Uri.parse('https://example.com'),
          idToken: 'idtok',
          device: {'id': 'dev123'},
        ),
        throwsA(_apiError('bad_response')),
      );
    });
  });

  group('N8nApi transport errors', () {
    test('wraps a client exception as network', () async {
      final api = N8nApi(
        client: MockClient((_) async => throw http.ClientException('x')),
      );

      expect(
        () => api.send('GET', Uri.parse('https://example.com/webhook/x')),
        throwsA(_apiError('network')),
      );
    });
  });
}

Matcher _apiError(String code) =>
    isA<N8nApiException>().having((e) => e.code, 'code', code);

N8nApiException _catchApiError(void Function() action) {
  try {
    action();
  } on N8nApiException catch (e) {
    return e;
  }
  fail('Expected an N8nApiException');
}
