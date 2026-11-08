import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/apps/app_models.dart';
import 'package:n8n_connect/features/server/n8n_api.dart';

void main() {
  final screens = [
    {
      'id': 'home',
      'title': 'Inicio',
      'components': [
        {'type': 'button'},
      ],
    },
    {'id': 'second', 'components': []},
  ];

  group('AppSummary.fromJson', () {
    test('reads a valid entry', () {
      final app = AppSummary.fromJson({
        'id': 'alarm',
        'name': 'Alarmas',
        'path': 'apps/alarm',
        'description': 'Despierta',
        'icon': 'alarm',
        'color': '#ff0000',
      })!;
      expect(app.id, 'alarm');
      expect(app.name, 'Alarmas');
      expect(app.path, 'apps/alarm');
      expect(app.description, 'Despierta');
      expect(app.icon, 'alarm');
      expect(app.color, '#ff0000');
    });

    test('returns null without id or path', () {
      expect(AppSummary.fromJson({'name': 'x', 'path': 'p'}), isNull);
      expect(AppSummary.fromJson({'id': 'x', 'name': 'x'}), isNull);
    });

    test('defaults icon to apps and description to empty', () {
      final app = AppSummary.fromJson({'id': 'x', 'path': 'p'})!;
      expect(app.icon, 'apps');
      expect(app.description, '');
    });
  });

  group('AppSpec.fromJson', () {
    test('respects a valid start screen', () {
      final spec = AppSpec.fromJson({'start': 'second', 'screens': screens});
      expect(spec.start, 'second');
    });

    test('uses the first screen when start is missing or unknown', () {
      expect(AppSpec.fromJson({'screens': screens}).start, 'home');
      expect(
        AppSpec.fromJson({'start': 'nope', 'screens': screens}).start,
        'home',
      );
    });

    test('copies state into initialState', () {
      final spec = AppSpec.fromJson({
        'state': {'hour': 7},
        'screens': screens,
      });
      expect(spec.initialState, {'hour': 7});
    });

    test('keeps components as maps', () {
      final spec = AppSpec.fromJson({'screens': screens});
      final component = spec.screen('home').components.single;
      expect(component, isA<Map<String, dynamic>>());
      expect(component['type'], 'button');
    });

    test('accepts screens given as a map keyed by id', () {
      final spec = AppSpec.fromJson({
        'screens': {
          'home': {'title': 'H', 'components': []},
        },
      });
      expect(spec.screens.keys.toList(), ['home']);
      expect(spec.screen('home').id, 'home');
      expect(spec.screen('home').title, 'H');
    });

    test('throws unsupported_spec for a newer schema', () {
      expect(
        () => AppSpec.fromJson({'schema': 2, 'screens': screens}),
        throwsA(
          isA<N8nApiException>().having(
            (e) => e.code,
            'code',
            'unsupported_spec',
          ),
        ),
      );
    });

    test('throws bad_spec without screens', () {
      expect(
        () => AppSpec.fromJson({'schema': 1}),
        throwsA(
          isA<N8nApiException>().having((e) => e.code, 'code', 'bad_spec'),
        ),
      );
    });

    group('refreshSeconds', () {
      Map<String, dynamic> withRefresh(Object? value) => {
        'screens': screens,
        if (value != null) 'refreshSeconds': value,
      };

      test('is null when absent', () {
        expect(AppSpec.fromJson(withRefresh(null)).refreshSeconds, isNull);
      });

      test('ignores values under 10 seconds', () {
        expect(AppSpec.fromJson(withRefresh(5)).refreshSeconds, isNull);
      });

      test('keeps values of 10 seconds or more', () {
        expect(AppSpec.fromJson(withRefresh(30)).refreshSeconds, 30);
      });

      test('accepts numbers written as text', () {
        expect(AppSpec.fromJson(withRefresh('30')).refreshSeconds, 30);
      });
    });

    test('screen() returns the start screen for an unknown id', () {
      final spec = AppSpec.fromJson({'start': 'second', 'screens': screens});
      expect(spec.screen('unknown').id, 'second');
    });
  });

  group('ActionResponse.fromJson', () {
    test('reads every field', () {
      final response = ActionResponse.fromJson({
        'message': 'Hecho',
        'state': {'count': 2},
        'screen': 'done',
        'actions': [
          {'type': 'toast', 'message': 'hola'},
        ],
        'spec': {
          'schema': 1,
          'start': 'done',
          'screens': [
            {'id': 'done', 'components': []},
          ],
        },
      });
      expect(response.message, 'Hecho');
      expect(response.state, {'count': 2});
      expect(response.screen, 'done');
      expect(response.actions, hasLength(1));
      expect(response.spec, isNotNull);
      expect(response.spec?.start, 'done');
    });

    test('empty json gives the defaults', () {
      final response = ActionResponse.fromJson({});
      expect(response.message, isNull);
      expect(response.state, equals({}));
      expect(response.actions, isEmpty);
      expect(response.spec, isNull);
    });
  });
}
