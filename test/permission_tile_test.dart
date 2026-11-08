import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/device_context/device_context.dart';
import 'package:n8n_connect/features/device_context/permission_tile.dart';
import 'package:n8n_connect/generated/l10n.dart';

/// Pumps a [PermissionTile] in a bare app. In tests the platform plugins are
/// missing, so `DeviceContext.status` reports `unavailable`.
Future<void> _pump(
  WidgetTester tester,
  DevicePermission permission, {
  String label = '',
  String description = '',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        body: ListView(
          children: [
            PermissionTile(
              permission: permission,
              label: label,
              description: description,
            ),
          ],
        ),
      ),
    ),
  );
  // Let the status read finish: platform replies arrive outside the fake
  // clock, so wait in real time. Without plugins it resolves to unavailable.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

void main() {
  testWidgets('location shows its default title', (tester) async {
    await _pump(tester, DevicePermission.location);

    expect(find.text('Location'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('location_always shows its default title', (tester) async {
    await _pump(tester, DevicePermission.locationAlways);

    expect(find.text('Location all the time'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('notifications shows its default title', (tester) async {
    await _pump(tester, DevicePermission.notifications);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('custom label and description replace the defaults', (
    tester,
  ) async {
    await _pump(
      tester,
      DevicePermission.notifications,
      label: 'Avisos',
      description: 'Para las alarmas',
    );

    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Para las alarmas'), findsOneWidget);
  });
}
