import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/alarms/alarms_page.dart';
import '../features/apps/app_runner_page.dart';
import '../features/apps/apps_home_page.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/login_page.dart';
import '../features/auth/verify_email_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/onboarding/onboarding_service.dart';
import '../features/push/push_inbox_page.dart';
import '../features/server/connect_server_page.dart';
import '../features/server/server_session.dart';
import '../features/settings/settings_page.dart';
import '../features/share/share_page.dart';
import '../features/startup/splash_page.dart';
import '../features/startup/startup_controller.dart';
import 'navigation.dart';

/// Where the user has to be, given startup, Firebase, server and tutorial
/// state: splash → welcome tutorial (first run only) → login → verify email →
/// connect server → apps.
@visibleForTesting
String? redirectFor({
  required String location,
  required bool ready,
  required bool signedIn,
  required bool needsEmailVerification,
  required bool connected,
  bool needsOnboarding = false,
}) {
  if (!ready) return location == '/splash' ? null : '/splash';
  if (needsOnboarding) return location == '/welcome' ? null : '/welcome';
  if (!signedIn) return location == '/login' ? null : '/login';
  if (needsEmailVerification) {
    return location == '/verify-email' ? null : '/verify-email';
  }
  const onboarding = {'/splash', '/welcome', '/login', '/verify-email'};
  if (!connected) {
    // Settings stays reachable (sign out, language) before connecting.
    return location == '/connect' || location == '/settings'
        ? null
        : '/connect';
  }
  if (onboarding.contains(location)) return '/';
  return null;
}

GoRouter createRouter({
  required StartupController startup,
  required AuthService auth,
  required ServerSession session,
  required OnboardingService onboarding,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([startup, auth, session, onboarding]),
    redirect: (context, state) => redirectFor(
      location: state.matchedLocation,
      ready: startup.ready,
      signedIn: auth.currentUser != null,
      needsEmailVerification: auth.needsEmailVerification,
      connected: session.isConnected,
      needsOnboarding: !onboarding.done,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/verify-email',
        builder: (_, _) => const VerifyEmailPage(),
      ),
      GoRoute(path: '/connect', builder: (_, _) => const ConnectServerPage()),
      GoRoute(path: '/', builder: (_, _) => const AppsHomePage()),
      GoRoute(
        path: '/apps/:appId',
        builder: (_, state) =>
            AppRunnerPage(appId: state.pathParameters['appId']!),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/inbox', builder: (_, _) => const PushInboxPage()),
      GoRoute(path: '/alarms', builder: (_, _) => const AlarmsPage()),
      GoRoute(path: '/share', builder: (_, _) => const SharePage()),
    ],
  );
}
