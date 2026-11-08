import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/app_router.dart';
import 'features/actions/action_executor.dart';
import 'features/actions/device_actions.dart';
import 'features/apps/apps_repository.dart';
import 'features/auth/auth_service.dart';
import 'features/automation/automation_consent.dart';
import 'features/onboarding/onboarding_service.dart';
import 'features/push/push_history.dart';
import 'features/push/push_service.dart';
import 'features/server/n8n_api.dart';
import 'features/server/server_session.dart';
import 'features/server/session_store.dart';
import 'features/settings/locale_service.dart';
import 'features/settings/theme_service.dart';
import 'features/share/share_intake.dart';
import 'features/startup/startup_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final localeService = LocaleService();
  await localeService.loadLocale();
  final onboarding = OnboardingService();
  await onboarding.load();
  final themeService = ThemeService();

  final auth = AuthService();
  final push = PushService();
  final pushHistory = PushHistory();
  final shareIntake = ShareIntake();
  final session = ServerSession(
    api: N8nApi(),
    store: SessionStore(),
    auth: auth,
    pushToken: push.token,
    onSessionClosed: () async {
      await push.deleteToken();
      await AutomationConsent.clearAll();
    },
  );
  // The inbox belongs to one account: wipe it when the Firebase user changes.
  var inboxOwner = auth.currentUser?.uid;
  auth.addListener(() {
    final uid = auth.currentUser?.uid;
    if (uid == inboxOwner) return;
    if (inboxOwner != null) unawaited(pushHistory.clear());
    inboxOwner = uid;
  });
  final apps = AppsRepository(session);
  final device = DeviceActions();
  final startup = StartupController(session: session, push: push);
  final router = createRouter(
    startup: startup,
    auth: auth,
    session: session,
    onboarding: onboarding,
  );
  final executor = ActionExecutor(
    device: device,
    notify: push.showSimple,
    openApp: (appId) => router.push('/apps/${Uri.encodeComponent(appId)}'),
    session: session,
  );

  unawaited(startup.start());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleService>.value(value: localeService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider<OnboardingService>.value(value: onboarding),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<ServerSession>.value(value: session),
        ChangeNotifierProvider<StartupController>.value(value: startup),
        Provider<PushService>.value(value: push),
        ChangeNotifierProvider<PushHistory>.value(value: pushHistory),
        Provider<ShareIntake>.value(value: shareIntake),
        Provider<AppsRepository>.value(value: apps),
        Provider<DeviceActions>.value(value: device),
        Provider<ActionExecutor>.value(value: executor),
      ],
      child: N8nConnectApp(router: router),
    ),
  );
}
