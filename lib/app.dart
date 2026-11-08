import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/navigation.dart';
import 'features/alarms/alarm_ring_listener.dart';
import 'features/push/push_event_handler.dart';
import 'features/settings/locale_service.dart';
import 'features/settings/theme_service.dart';
import 'features/share/share_listener.dart';
import 'generated/l10n.dart';

class N8nConnectApp extends StatelessWidget {
  const N8nConnectApp({super.key, required this.router});

  final GoRouter router;

  static const Color _seed = Color(0xFFEA4B71); // n8n pink

  @override
  Widget build(BuildContext context) {
    final localeService = context.watch<LocaleService>();
    final themeService = context.watch<ThemeService>();

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
      locale: localeService.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FirebaseUILocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      themeMode: themeService.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: _seed,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _seed,
      ),
      builder: (context, child) => PushEventHandler(
        onOpenApp: (appId) =>
            router.push('/apps/${Uri.encodeComponent(appId)}'),
        child: AlarmRingListener(
          child: ShareListener(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
