import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/apps/spec_view.dart';
import 'package:n8n_connect/generated/l10n.dart';

/// Pumps [components] in a bare app and returns the list that collects every
/// `onChanged(key, value)` call.
Future<List<MapEntry<String, Object?>>> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> components, {
  Map<String, dynamic> state = const <String, dynamic>{},
}) async {
  final changes = <MapEntry<String, Object?>>[];
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
        body: SingleChildScrollView(
          child: SpecView(
            components: components,
            state: state,
            onChanged: (key, value) => changes.add(MapEntry(key, value)),
            onActions: (_) async {},
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  testWidgets('checkbox tap stores true', (tester) async {
    final changes = await _pump(tester, [
      {'type': 'checkbox', 'key': 'ok', 'label': 'Acepto'},
    ]);

    await tester.tap(find.text('Acepto'));
    await tester.pump();

    expect(changes.single.key, 'ok');
    expect(changes.single.value, true);
  });

  testWidgets('multiselect toggles options in option order', (tester) async {
    final changes = await _pump(
      tester,
      [
        {
          'type': 'multiselect',
          'key': 'tags',
          'options': [
            {'value': 'a'},
            {'value': 'b'},
          ],
        },
      ],
      state: {
        'tags': ['a'],
      },
    );

    await tester.tap(find.widgetWithText(FilterChip, 'b'));
    await tester.pump();
    expect(changes.last.key, 'tags');
    expect(changes.last.value, ['a', 'b']);

    // The state is not updated by the test, so 'a' is still selected here.
    await tester.tap(find.widgetWithText(FilterChip, 'a'));
    await tester.pump();
    expect(changes.last.value, <String>[]);
  });

  testWidgets('stepper add stores the next integer', (tester) async {
    final changes = await _pump(
      tester,
      [
        {'type': 'stepper', 'key': 'n', 'label': 'Vasos', 'min': 0, 'max': 10},
      ],
      state: {'n': 5},
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(changes.single.key, 'n');
    expect(changes.single.value, 6);
  });

  testWidgets('stepper disables remove at the minimum', (tester) async {
    await _pump(
      tester,
      [
        {'type': 'stepper', 'key': 'n', 'label': 'Vasos', 'min': 0, 'max': 10},
      ],
      state: {'n': 0},
    );

    final remove = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(remove.onPressed, isNull);
  });

  testWidgets('slider shows its label and value with unit', (tester) async {
    await _pump(
      tester,
      [
        {
          'type': 'slider',
          'key': 'vol',
          'label': 'Volumen',
          'min': 0,
          'max': 100,
          'unit': '%',
        },
      ],
      state: {'vol': 30},
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Volumen'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
  });

  testWidgets('progress shows the percentage', (tester) async {
    await _pump(tester, [
      {'type': 'progress', 'value': 50},
    ]);

    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('metric shows value and unit', (tester) async {
    await _pump(tester, [
      {
        'type': 'metric',
        'label': 'Temperatura',
        'value': '21',
        'unit': '°C',
        'tone': 'success',
      },
    ]);

    expect(find.text('Temperatura'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('°C'), findsOneWidget);
  });

  testWidgets('table shows a header and a templated cell', (tester) async {
    await _pump(
      tester,
      [
        {
          'type': 'table',
          'columns': ['Nombre', 'Valor'],
          'rows': [
            ['{{name}}', '1'],
            ['solo'],
          ],
        },
      ],
      state: {'name': 'Ana'},
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('solo'), findsOneWidget);
  });

  testWidgets('grid renders all of its children', (tester) async {
    await _pump(tester, [
      {
        'type': 'grid',
        'columns': 2,
        'components': [
          {'type': 'text', 'text': 'Uno'},
          {'type': 'text', 'text': 'Dos'},
          {'type': 'text', 'text': 'Tres'},
        ],
      },
    ]);

    expect(find.text('Uno'), findsOneWidget);
    expect(find.text('Dos'), findsOneWidget);
    expect(find.text('Tres'), findsOneWidget);
  });

  testWidgets('component with visible false is not rendered', (tester) async {
    await _pump(
      tester,
      [
        {'type': 'text', 'text': 'Siempre'},
        {'type': 'text', 'text': 'Oculto', 'visible': '{{flag}}'},
      ],
      state: {'flag': false},
    );

    expect(find.text('Siempre'), findsOneWidget);
    expect(find.text('Oculto'), findsNothing);
  });
}
