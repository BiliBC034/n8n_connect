import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n8n_connect/features/onboarding/onboarding_page.dart';
import 'package:n8n_connect/features/onboarding/onboarding_service.dart';
import 'package:n8n_connect/generated/l10n.dart';

/// Same localization setup as the app, pinned to English.
Widget _app(OnboardingService service) =>
    ChangeNotifierProvider<OnboardingService>.value(
      value: service,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const OnboardingPage(),
      ),
    );

void main() {
  setUpAll(() => AppLocalizations.delegate.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OnboardingService', () {
    test('is not done when nothing is saved', () async {
      final service = OnboardingService();
      await service.load();
      expect(service.done, isFalse);
    });

    test('complete() is saved and a new instance reads it', () async {
      final service = OnboardingService();
      await service.load();
      await service.complete();
      expect(service.done, isTrue);

      final reopened = OnboardingService();
      await reopened.load();
      expect(reopened.done, isTrue);
    });

    test('reset() shows the tutorial again', () async {
      final service = OnboardingService();
      await service.complete();
      await service.reset();
      expect(service.done, isFalse);

      final reopened = OnboardingService();
      await reopened.load();
      expect(reopened.done, isFalse);
    });

    test('no saved keys means the tutorial is not done', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OnboardingService();
      await service.load();
      expect(service.done, isFalse);
    });

    test(
      'a saved server URL without the flag counts as seen and is saved',
      () async {
        SharedPreferences.setMockInitialValues({
          'nc.serverUrl': 'https://n8n.example.com',
        });
        final service = OnboardingService();
        await service.load();
        expect(service.done, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('onboarding_done'), isTrue);

        final reopened = OnboardingService();
        await reopened.load();
        expect(reopened.done, isTrue);
      },
    );

    test(
      'an explicit false keeps the tutorial even with a server URL',
      () async {
        SharedPreferences.setMockInitialValues({
          'nc.serverUrl': 'https://n8n.example.com',
          'onboarding_done': false,
        });
        final service = OnboardingService();
        await service.load();
        expect(service.done, isFalse);
      },
    );
  });

  group('OnboardingPage', () {
    testWidgets('Next goes through the pages, Get started marks it done', (
      tester,
    ) async {
      final service = OnboardingService();
      await tester.pumpWidget(_app(service));

      final l10n = AppLocalizations.current;
      expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text(l10n.onboardingNext));
        await tester.pumpAndSettle();
      }
      expect(find.text(l10n.onboardingDone), findsOneWidget);
      expect(service.done, isFalse);

      await tester.tap(find.text(l10n.onboardingDone));
      await tester.pumpAndSettle();
      expect(service.done, isTrue);
    });

    testWidgets('fits a 360 dp phone in light and dark themes', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final brightness in Brightness.values) {
        final service = OnboardingService();
        // A key per theme, so each run starts again on the first page.
        await tester.pumpWidget(
          ChangeNotifierProvider<OnboardingService>.value(
            key: ValueKey<Brightness>(brightness),
            value: service,
            child: MaterialApp(
              theme: ThemeData(
                colorSchemeSeed: const Color(0xFFEA4B71),
                brightness: brightness,
              ),
              locale: const Locale('es'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              home: const OnboardingPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Any overflow is reported as a test failure.
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text(AppLocalizations.current.onboardingNext));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(
          find.text(AppLocalizations.current.onboardingDone),
          findsOneWidget,
        );
      }
    });

    testWidgets('Skip marks it done', (tester) async {
      final service = OnboardingService();
      await tester.pumpWidget(_app(service));

      await tester.tap(find.text(AppLocalizations.current.onboardingSkip));
      await tester.pumpAndSettle();
      expect(service.done, isTrue);
    });
  });
}
