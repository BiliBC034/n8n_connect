import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';
import '../../core/log.dart';
import '../../firebase_options.dart';
import '../automation/background_automation.dart';
import 'push_payload.dart';

/// Runs in a background isolate when a data message arrives while the app is
/// not in the foreground: it only shows a notification. Starting activities
/// (alarm, calendar…) from the background is blocked by Android, so the
/// actions run when the user taps "Run" and the app comes to the front.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final payload = PushPayload.fromData(message.data);
  // Messages with a "notification" block are displayed by the system itself.
  if (payload == null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(PushService.initializationSettings);
  // Automations the user allowed for that app run right here, unattended.
  try {
    if (await BackgroundAutomation.handleInBackground(payload, plugin)) return;
  } catch (e) {
    appLog('Push', 'background automation failed: $e');
  }
  await PushService.showPayloadNotification(plugin, payload);
}

enum PushOrigin {
  /// Received while the app was open.
  foreground,

  /// The user tapped the notification body.
  tap,

  /// The user pressed the notification's "Run" button.
  runButton,
}

class PushEvent {
  const PushEvent(this.payload, this.origin);

  final PushPayload payload;
  final PushOrigin origin;
}

/// FCM + local notifications plumbing. UI decisions (confirm, run) are taken
/// by `PushEventHandler`, which consumes [events].
class PushService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Single-subscription: events received before the UI is ready are buffered.
  final StreamController<PushEvent> _events = StreamController<PushEvent>();
  final Set<String> _seen = <String>{};

  static const String _autoRunKey = 'nc.push.autoRun';
  static const String runActionId = 'run';

  /// Called when FCM rotates the device token.
  void Function()? onTokenChanged;

  bool _autoRun = false;

  /// Run foreground pushes without asking (per-action `confirm` still applies).
  bool get autoRun => _autoRun;

  Stream<PushEvent> get events => _events.stream;

  static const InitializationSettings initializationSettings =
      InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );

  Future<void> init() async {
    _autoRun =
        (await SharedPreferences.getInstance()).getBool(_autoRunKey) ?? false;

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel());

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromSystem);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      onTokenChanged?.call();
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _onOpenedFromSystem(initial);

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      _onNotificationResponse(response);
    }
  }

  Future<String?> token() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      appLog('Push', 'FCM token unavailable: $e');
      return null;
    }
  }

  /// Invalidates this device's FCM token (a new one is issued on next use),
  /// so pushes addressed to a closed session can no longer arrive.
  Future<void> deleteToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      appLog('Push', 'could not delete FCM token: $e');
    }
  }

  /// Android 13+ asks the user; earlier versions grant it at install.
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> setAutoRun(bool value) async {
    _autoRun = value;
    await (await SharedPreferences.getInstance()).setBool(_autoRunKey, value);
  }

  /// Plain notification (the `notify` action, or FCM notifications received
  /// while the app is open).
  Future<void> showSimple(String title, String body) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title,
      body,
      NotificationDetails(android: _androidDetails()),
    );
  }

  static Future<void> showPayloadNotification(
    FlutterLocalNotificationsPlugin plugin,
    PushPayload payload,
  ) async {
    final spanish = PlatformDispatcher.instance.locale.languageCode == 'es';
    final hasActions = payload.rawActions.isNotEmpty;
    await plugin.show(
      payload.notificationId,
      payload.title.isEmpty ? 'n8n Connect' : payload.title,
      payload.body,
      NotificationDetails(
        android: _androidDetails(
          actions: hasActions
              ? [
                  AndroidNotificationAction(
                    runActionId,
                    spanish ? 'Ejecutar' : 'Run',
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                ]
              : null,
        ),
      ),
      payload: payload.encode(),
    );
  }

  static AndroidNotificationChannel _channel() =>
      const AndroidNotificationChannel(
        AppConfig.pushChannelId,
        'n8n',
        description: 'Actions and messages from your n8n workflows',
        importance: Importance.high,
      );

  static AndroidNotificationDetails _androidDetails({
    List<AndroidNotificationAction>? actions,
  }) {
    final channel = _channel();
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      actions: actions,
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    final payload = PushPayload.fromData(message.data);
    if (payload != null) {
      _emit(payload, PushOrigin.foreground);
      return;
    }
    final notification = message.notification;
    if (notification != null) {
      unawaited(showSimple(notification.title ?? '', notification.body ?? ''));
    }
  }

  void _onOpenedFromSystem(RemoteMessage message) {
    final payload = PushPayload.fromData(message.data);
    if (payload != null) _emit(payload, PushOrigin.tap);
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = PushPayload.decode(response.payload);
    if (payload == null) return;
    _emit(
      payload,
      response.actionId == runActionId ? PushOrigin.runButton : PushOrigin.tap,
    );
  }

  void _emit(PushPayload payload, PushOrigin origin) {
    if (!_seen.add(payload.id)) return;
    _events.add(PushEvent(payload, origin));
  }
}
