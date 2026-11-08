import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/log.dart';
import '../../generated/l10n.dart';
import '../actions/action_executor.dart';
import '../actions/action_spec.dart';
import '../actions/device_actions.dart';
import '../alarms/alarm_engine.dart';
import '../auth/auth_service.dart';
import '../push/push_history.dart';
import '../push/push_payload.dart';
import '../server/n8n_api.dart';
import '../server/server_session.dart';
import '../server/session_store.dart';
import 'automation_consent.dart';

/// What to do with a push, given the stored session and the app's consent.
enum AutomationDecision {
  /// Run its actions now, without asking.
  run,

  /// Not for the connected account (or nobody is connected): drop it unseen.
  drop,

  /// Show it and let the user decide (no consent, or actions that need UI).
  ask,
}

/// Pushes that run on their own: the app sent them has automation allowed
/// (see [AutomationConsent]), every action is in [automaticActionTypes] and
/// none asks for confirmation.
class BackgroundAutomation {
  BackgroundAutomation._();

  static Future<AutomationDecision> decide(
    PushPayload payload, {
    required Uri? server,
    required String? email,
  }) async {
    if (server == null) return AutomationDecision.drop;
    final recipient = payload.recipient;
    if (recipient != null && recipient != email?.toLowerCase()) {
      return AutomationDecision.drop;
    }
    final app = payload.appId;
    final actions = payload.actions;
    final automatic =
        app != null &&
        actions.isNotEmpty &&
        actions.every(
          (a) => automaticActionTypes.contains(a.type) && a.confirm == null,
        );
    if (!automatic || !await AutomationConsent.isAllowed(server, app)) {
      return AutomationDecision.ask;
    }
    return AutomationDecision.run;
  }

  /// Called from the FCM background isolate. Returns true when the push was
  /// handled here (run or dropped) and must not be shown as a notification.
  static Future<bool> handleInBackground(
    PushPayload payload,
    FlutterLocalNotificationsPlugin notifications,
  ) async {
    final store = SessionStore();
    final stored = await store.read();
    final decision = await decide(
      payload,
      server: stored?.baseUrl,
      email: stored?.user.email,
    );
    if (decision == AutomationDecision.drop) return true;
    if (decision == AutomationDecision.ask) return false;

    // This isolate has no widgets: load the strings and services by hand.
    await AppLocalizations.load(
      Locale(PlatformDispatcher.instance.locale.languageCode),
    );
    await AlarmEngine.init();
    final session = ServerSession(
      api: N8nApi(),
      store: store,
      auth: AuthService(),
      pushToken: FirebaseMessaging.instance.getToken,
    );
    await session.restore();

    Future<void> notify(String title, String body) => notifications.show(
      DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'n8n_connect_actions',
          'n8n',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    final executor = ActionExecutor(
      device: DeviceActions(),
      notify: notify,
      openApp: (_) {},
      session: session,
    );
    final ok = await executor.run(
      payload.actions,
      askConfirmation: false,
      appId: payload.appId,
      automaticOnly: true,
    );
    appLog('Automation', '${payload.appId}: ${ok ? 'done' : 'failed'}');
    await PushHistory.recordFromBackground(
      payload,
      ok ? PushStatus.executed : PushStatus.failed,
    );
    if (!ok) {
      final l10n = AppLocalizations.current;
      await notify(
        l10n.automationFailedTitle,
        payload.title.isEmpty ? (payload.appId ?? '') : payload.title,
      );
    }
    return true;
  }
}
