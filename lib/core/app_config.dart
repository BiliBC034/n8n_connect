import '../firebase_web_client.dart';

/// Constants of the n8n Connect protocol (v1) shared with the n8n workflows.
///
/// Every path is relative to `{serverUrl}/webhook/`. See docs/PROTOCOL.md.
class AppConfig {
  AppConfig._();

  /// Highest protocol version this app understands.
  static const int protocolVersion = 1;

  /// Highest UI spec schema version this app can render.
  static const int specSchemaVersion = 1;

  static const String infoPath = 'n8n-connect/info';
  static const String authPath = 'n8n-connect/auth';
  static const String appsPath = 'n8n-connect/apps';
  static const String logoutPath = 'n8n-connect/logout';

  /// Receives text/links shared from other apps ("Share → n8n Connect").
  static const String sharePath = 'n8n-connect/share';

  /// OAuth web client ID for the Google sign-in button, defined in the local
  /// lib/firebase_web_client.dart. Empty means no Google sign-in.
  static const String googleClientId = firebaseWebClientId;

  static const Duration requestTimeout = Duration(seconds: 20);

  /// Submits can run long workflows (e.g. a booking that takes ~30 s).
  static const Duration submitTimeout = Duration(seconds: 150);

  /// Refresh the server session this long before it expires.
  static const Duration sessionRefreshMargin = Duration(minutes: 2);

  static const String pushChannelId = 'n8n_connect_actions';
}
