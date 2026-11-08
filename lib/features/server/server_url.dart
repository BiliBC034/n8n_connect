enum ServerUrlError { empty, invalid, insecure, foreignOrigin }

class ServerUrlException implements Exception {
  const ServerUrlException(this.error);

  final ServerUrlError error;

  @override
  String toString() => 'ServerUrlException(${error.name})';
}

/// Path segments of the n8n editor/webhook routes. Anything from the first of
/// these onwards is dropped, so pasting a webhook or editor URL still yields
/// the server root.
const Set<String> _n8nRouteSegments = {
  'webhook',
  'webhook-test',
  'webhook-waiting',
  'form',
  'form-test',
  'home',
  'workflow',
  'workflows',
  'projects',
  'credentials',
  'executions',
  'settings',
  'signin',
  'setup',
  'rest',
  'api',
};

/// Turns what the user typed into the server base URL.
///
/// HTTPS only: the app sends Firebase ID tokens and session tokens to this
/// host, so plain HTTP is rejected.
Uri normalizeServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) throw const ServerUrlException(ServerUrlError.empty);
  if (!text.contains('://')) text = 'https://$text';

  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    throw const ServerUrlException(ServerUrlError.invalid);
  }
  if (uri.scheme == 'http') {
    throw const ServerUrlException(ServerUrlError.insecure);
  }
  if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    throw const ServerUrlException(ServerUrlError.invalid);
  }

  final segments = <String>[];
  for (final segment in uri.pathSegments) {
    if (segment.isEmpty) continue;
    if (_n8nRouteSegments.contains(segment)) break;
    segments.add(segment);
  }
  return Uri(
    scheme: 'https',
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    pathSegments: segments,
  );
}

/// Resolves a webhook path (`n8n-connect/apps`) or an absolute URL against the
/// server base URL.
///
/// Absolute URLs must point at this server's webhooks (same origin, under
/// `{base}/webhook/`): the session token is attached to these requests, so a
/// spec must never be able to send it anywhere else.
Uri webhookUri(Uri base, String pathOrUrl, {Map<String, String>? query}) {
  final raw = pathOrUrl.trim();
  Uri target;
  if (raw.startsWith('https://') || raw.startsWith('http://')) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null) throw const ServerUrlException(ServerUrlError.invalid);
    target = parsed;
    final sameServer =
        target.scheme == 'https' &&
        target.host.toLowerCase() == base.host &&
        target.port == base.port &&
        target.path.startsWith('${base.path}/webhook/');
    if (!sameServer) {
      throw const ServerUrlException(ServerUrlError.foreignOrigin);
    }
  } else {
    var path = raw.replaceFirst(RegExp(r'^/+'), '');
    if (path.startsWith('webhook/')) path = path.substring('webhook/'.length);
    final relative = Uri.parse(path);
    final segments = relative.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.any((s) => s == '..' || s == '.')) {
      throw const ServerUrlException(ServerUrlError.invalid);
    }
    target = base.replace(
      pathSegments: [...base.pathSegments, 'webhook', ...segments],
      query: relative.hasQuery ? relative.query : null,
    );
  }
  if (query != null && query.isNotEmpty) {
    target = target.replace(
      queryParameters: {...target.queryParameters, ...query},
    );
  }
  return target;
}
