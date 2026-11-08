import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/core/app_router.dart';

/// Shorthand for [redirectFor] with the state fields that a case does not
/// care about set to their most common values.
String? _redirect(
  String location, {
  bool ready = true,
  bool signedIn = true,
  bool needsEmailVerification = false,
  bool connected = true,
  bool needsOnboarding = false,
}) => redirectFor(
  location: location,
  ready: ready,
  signedIn: signedIn,
  needsEmailVerification: needsEmailVerification,
  connected: connected,
  needsOnboarding: needsOnboarding,
);

void main() {
  group('redirectFor before startup is ready', () {
    test('sends every location to splash, and stays on splash', () {
      expect(_redirect('/', ready: false, signedIn: false), '/splash');
      expect(_redirect('/splash', ready: false, signedIn: false), isNull);
    });
  });

  group('redirectFor during the first-run tutorial', () {
    test('sends every location to welcome, and stays there', () {
      for (final location in ['/', '/login', '/apps/x']) {
        expect(
          _redirect(location, needsOnboarding: true),
          '/welcome',
          reason: location,
        );
      }
      expect(_redirect('/welcome', needsOnboarding: true), isNull);
    });

    test('splash still comes first', () {
      expect(_redirect('/', ready: false, needsOnboarding: true), '/splash');
    });

    test('after the tutorial, welcome follows the normal flow', () {
      expect(_redirect('/welcome'), '/');
      expect(_redirect('/welcome', signedIn: false), '/login');
      expect(_redirect('/welcome', connected: false), '/connect');
    });
  });

  group('redirectFor when signed out', () {
    test('sends every location to login, and stays on login', () {
      expect(_redirect('/', signedIn: false), '/login');
      expect(_redirect('/login', signedIn: false), isNull);
    });
  });

  group('redirectFor when email verification is pending', () {
    test('sends every location to verify-email, and stays there', () {
      expect(_redirect('/', needsEmailVerification: true), '/verify-email');
      expect(_redirect('/verify-email', needsEmailVerification: true), isNull);
    });
  });

  group('redirectFor when signed in but not connected', () {
    test('sends apps to connect, and allows connect and settings', () {
      expect(_redirect('/', connected: false), '/connect');
      expect(_redirect('/apps/x', connected: false), '/connect');
      expect(_redirect('/settings', connected: false), isNull);
      expect(_redirect('/connect', connected: false), isNull);
    });
  });

  group('redirectFor when connected', () {
    test('leaves onboarding pages for the home page', () {
      for (final location in ['/splash', '/login', '/verify-email']) {
        expect(_redirect(location), '/', reason: location);
      }
    });

    test('keeps the app pages where they are', () {
      for (final location in ['/connect', '/apps/gym', '/settings', '/']) {
        expect(_redirect(location), isNull, reason: location);
      }
    });
  });
}
