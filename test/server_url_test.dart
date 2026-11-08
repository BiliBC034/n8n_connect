import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/server/server_url.dart';

void main() {
  group('normalizeServerUrl', () {
    test('adds https to a bare host', () {
      expect(
        normalizeServerUrl('n8n.example.com').toString(),
        'https://n8n.example.com',
      );
    });

    test('trims spaces, lowercases the host and keeps the port', () {
      expect(
        normalizeServerUrl(' https://N8N.Example.com:2096/ ').toString(),
        'https://n8n.example.com:2096',
      );
    });

    test('drops a webhook path and its query', () {
      expect(
        normalizeServerUrl(
          'https://n8n.example.com:2096/webhook/a1b2c3d4',
        ).toString(),
        'https://n8n.example.com:2096',
      );
    });

    test('keeps a sub-path prefix but drops editor routes', () {
      expect(
        normalizeServerUrl('https://example.com/n8n/home/workflows').toString(),
        'https://example.com/n8n',
      );
    });

    test('drops a workflow route at the root', () {
      expect(
        normalizeServerUrl('https://example.com/workflow/abc').toString(),
        'https://example.com',
      );
    });

    test('drops query and fragment', () {
      expect(
        normalizeServerUrl('https://example.com/?a=1#x').toString(),
        'https://example.com',
      );
    });

    test('rejects http with insecure', () {
      expect(
        () => normalizeServerUrl('http://example.com'),
        throwsA(_serverUrlError(ServerUrlError.insecure)),
      );
    });

    test('rejects empty and blank input with empty', () {
      expect(
        () => normalizeServerUrl(''),
        throwsA(_serverUrlError(ServerUrlError.empty)),
      );
      expect(
        () => normalizeServerUrl('   '),
        throwsA(_serverUrlError(ServerUrlError.empty)),
      );
    });

    test('rejects other schemes, user info and a missing host as invalid', () {
      for (final input in [
        'ftp://example.com',
        'https://user:pw@example.com',
        'https://',
      ]) {
        expect(
          () => normalizeServerUrl(input),
          throwsA(_serverUrlError(ServerUrlError.invalid)),
          reason: input,
        );
      }
    });
  });
}

Matcher _serverUrlError(ServerUrlError error) =>
    isA<ServerUrlException>().having((e) => e.error, 'error', error);
