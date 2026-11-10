import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/actions/action_executor.dart';
import 'package:n8n_connect/features/actions/device_actions.dart';
import 'package:n8n_connect/features/apps/app_models.dart';
import 'package:n8n_connect/features/apps/app_runner_page.dart';
import 'package:n8n_connect/features/apps/apps_repository.dart';
import 'package:n8n_connect/generated/l10n.dart';
import 'package:provider/provider.dart';

/// A tall screen: 60 lines of text.
List<Map<String, dynamic>> _tall(String prefix) => [
  for (var i = 0; i < 60; i++) {'type': 'text', 'text': '$prefix $i'},
];

Map<String, dynamic> _specJson() => {
  'schema': 1,
  'start': 'home',
  'screens': [
    {'id': 'home', 'components': _tall('home')},
    {'id': 'list', 'components': _tall('list')},
    {'id': 'detail', 'components': _tall('detail')},
  ],
};

class _FakeRepository implements AppsRepository {
  ActionResponse next = ActionResponse.fromJson(const {});

  @override
  Future<AppSummary> find(String id) async =>
      const AppSummary(id: 'demo', name: 'Demo', path: 'n8n-connect/apps/demo');

  /// Time a spec load takes: long enough for the spinner to replace the list.
  Duration loadDelay = Duration.zero;

  @override
  Future<CachedResult<AppSpec>> loadSpec(AppSummary app) async {
    await Future<void>.delayed(loadDelay);
    return CachedResult(AppSpec.fromJson(_specJson()));
  }

  @override
  Future<ActionResponse> submit(
    String path,
    String method,
    Map<String, dynamic> payload,
  ) async => next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => AppLocalizations.delegate.load(const Locale('en')));

  late _FakeRepository repository;

  Future<ActionHost> pumpRunner(WidgetTester tester) async {
    repository = _FakeRepository();
    final executor = ActionExecutor(
      device: DeviceActions(),
      notify: (title, body) async {},
      openApp: (_) {},
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppsRepository>.value(value: repository),
          Provider<ActionExecutor>.value(value: executor),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: const AppRunnerPage(appId: 'demo'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(AppRunnerPage)) as ActionHost;
  }

  ScrollController controller(WidgetTester tester) =>
      tester.widget<ListView>(find.byType(ListView)).controller!;

  Future<void> scrollTo(WidgetTester tester, double offset) async {
    controller(tester).jumpTo(offset);
    await tester.pump();
  }

  testWidgets('a new screen starts at the top and back restores the offset', (
    tester,
  ) async {
    final host = await pumpRunner(tester);
    await scrollTo(tester, 800);

    host.navigate('detail');
    await tester.pumpAndSettle();
    expect(find.text('detail 0'), findsOneWidget);
    expect(controller(tester).offset, 0);

    await scrollTo(tester, 500);
    host.back();
    await tester.pumpAndSettle();
    expect(controller(tester).offset, 800);

    // Opening it again is a new visit: top again.
    host.navigate('detail');
    await tester.pumpAndSettle();
    expect(controller(tester).offset, 0);
  });

  testWidgets('a response that rebuilds the stack keeps the screens offsets', (
    tester,
  ) async {
    final host = await pumpRunner(tester);
    await scrollTo(tester, 800);
    host.navigate('list');
    await tester.pumpAndSettle();
    await scrollTo(tester, 600);

    // Like the n8n app: the whole spec plus the navigation back to the list
    // and on to the detail.
    repository.next = ActionResponse.fromJson({
      'spec': _specJson(),
      'screen': 'list',
      'actions': [
        {'type': 'navigate', 'screen': 'detail'},
      ],
    });
    await host.submit({'path': 'n8n-connect/apps/demo/view'});
    await tester.pumpAndSettle();
    expect(find.text('detail 0'), findsOneWidget);
    expect(controller(tester).offset, 0);

    host.back();
    await tester.pumpAndSettle();
    expect(controller(tester).offset, 600);
    host.back();
    await tester.pumpAndSettle();
    expect(controller(tester).offset, 800);
  });

  testWidgets('refreshing the screen on top keeps its position', (
    tester,
  ) async {
    final host = await pumpRunner(tester);
    host.navigate('list');
    await tester.pumpAndSettle();
    await scrollTo(tester, 700);

    repository.next = ActionResponse.fromJson({
      'spec': _specJson(),
      'screen': 'list',
    });
    await host.submit({'path': 'n8n-connect/apps/demo/view'});
    await tester.pumpAndSettle();
    expect(find.text('list 0', skipOffstage: false), findsOneWidget);
    expect(controller(tester).offset, 700);
  });

  testWidgets('a reload behind a spinner keeps the latest offset', (
    tester,
  ) async {
    final host = await pumpRunner(tester);
    repository.loadDelay = const Duration(milliseconds: 300);
    await scrollTo(tester, 800);
    host.navigate('list');
    await tester.pumpAndSettle();
    host.back();
    await tester.pumpAndSettle();
    expect(controller(tester).offset, 800);

    await scrollTo(tester, 100);
    final reload = host.reload();
    await tester.pump();
    expect(find.byType(ListView), findsNothing); // spinner
    await tester.pumpAndSettle();
    await reload;
    expect(controller(tester).offset, 100);
  });

  testWidgets('reload plus navigate back to the open screen keeps it', (
    tester,
  ) async {
    final host = await pumpRunner(tester);
    repository.loadDelay = const Duration(milliseconds: 300);
    host.navigate('list');
    await tester.pumpAndSettle();
    await scrollTo(tester, 700);

    repository.next = ActionResponse.fromJson({
      'actions': [
        {'type': 'reload'},
        {'type': 'navigate', 'screen': 'list'},
      ],
    });
    // The reload waits for the spec: pump while the submit runs.
    final submit = host.submit({'path': 'n8n-connect/apps/demo/save'});
    await tester.pumpAndSettle();
    await submit;
    expect(find.text('list 0', skipOffstage: false), findsOneWidget);
    expect(controller(tester).offset, 700);
  });

  testWidgets('a templated destination that was not open starts at the top', (
    tester,
  ) async {
    final host = await pumpRunner(tester);
    host.navigate('detail');
    await tester.pumpAndSettle();
    await scrollTo(tester, 500);
    host.back();
    await tester.pumpAndSettle();

    repository.next = ActionResponse.fromJson({
      'state': {'next': 'detail'},
      'actions': [
        {'type': 'navigate', 'screen': '{{next}}'},
      ],
    });
    await host.submit({'path': 'n8n-connect/apps/demo/view'});
    await tester.pumpAndSettle();
    expect(find.text('detail 0'), findsOneWidget);
    expect(controller(tester).offset, 0);
  });
}
