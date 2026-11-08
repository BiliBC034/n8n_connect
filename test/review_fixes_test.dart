import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/core/json.dart';
import 'package:n8n_connect/features/push/push_payload.dart';
import 'package:n8n_connect/features/server/server_url.dart';

// Regressions found in the final review.
void main() {
  group('non-finite numbers', () {
    test('asInt rejects NaN and Infinity', () {
      expect(asInt(double.nan), isNull);
      expect(asInt(double.infinity), isNull);
      expect(asInt('NaN'), isNull);
      expect(asInt('Infinity'), isNull);
      expect(asInt('1e999'), isNull);
      expect(asInt('7'), 7);
      expect(asInt('7.9'), 7);
    });

    test('asDouble rejects NaN and Infinity', () {
      expect(asDouble(double.nan), isNull);
      expect(asDouble('Infinity'), isNull);
      expect(asDouble('1,5'), 1.5);
    });
  });

  group('webhookUri with absolute URLs', () {
    final base = normalizeServerUrl('https://example.com/n8n');

    test('accepts URLs under the server webhook root', () {
      expect(
        webhookUri(base, 'https://example.com/n8n/webhook/x').toString(),
        'https://example.com/n8n/webhook/x',
      );
    });

    test('rejects other paths of the same host', () {
      for (final url in [
        'https://example.com/other-service/x',
        'https://example.com/n8n/rest/x',
        'https://example.com/n8n/webhook/../rest/x',
      ]) {
        expect(
          () => webhookUri(base, url),
          throwsA(
            isA<ServerUrlException>().having(
              (e) => e.error,
              'error',
              ServerUrlError.foreignOrigin,
            ),
          ),
          reason: url,
        );
      }
    });

    test('malformed absolute URL is invalid, not a FormatException', () {
      expect(
        () => webhookUri(base, 'https://[bad'),
        throwsA(isA<ServerUrlException>()),
      );
    });
  });

  group('push recipient', () {
    test('reads and normalises "to"', () {
      final payload = PushPayload.fromData({
        'nc': '1',
        'id': 'a',
        'to': ' Ana@Example.com ',
      })!;
      expect(payload.recipient, 'ana@example.com');
      expect(
        PushPayload.decode(payload.encode())!.recipient,
        'ana@example.com',
      );
    });

    test('empty "to" means any connected account', () {
      expect(PushPayload.fromData({'nc': '1', 'to': ''})!.recipient, isNull);
    });
  });
}
