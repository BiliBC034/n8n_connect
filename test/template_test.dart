import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/core/template.dart';

void main() {
  group('Template.render', () {
    test('replaces a placeholder with the state value', () {
      expect(Template.render('Hola {{name}}', {'name': 'Ana'}), 'Hola Ana');
    });

    test('missing key renders as empty text', () {
      expect(Template.render('Hola {{name}}', {}), 'Hola ');
    });

    test('accepts spaces inside the braces', () {
      expect(Template.render('{{ name }}', {'name': 'Ana'}), 'Ana');
    });

    test('resolves dotted paths into nested maps', () {
      expect(
        Template.render('{{user.name}}', {
          'user': {'name': 'Ana'},
        }),
        'Ana',
      );
    });

    test('resolves list indexes in dotted paths', () {
      expect(
        Template.render('{{items.1}}', {
          'items': ['a', 'b'],
        }),
        'b',
      );
    });

    test('returns text without placeholders unchanged', () {
      expect(Template.render('sin nada', {'name': 'x'}), 'sin nada');
    });
  });

  group('Template.resolve', () {
    test('a string that is exactly one placeholder keeps an int', () {
      expect(Template.resolve('{{hour}}', {'hour': 7}), 7);
    });

    test('a string that is exactly one placeholder keeps a bool', () {
      expect(Template.resolve('{{flag}}', {'flag': true}), true);
    });

    test('surrounding spaces still count as a whole placeholder', () {
      expect(Template.resolve(' {{hour}} ', {'hour': 7}), 7);
    });

    test('mixed text turns the value into a string', () {
      expect(Template.resolve('h{{hour}}', {'hour': 7}), 'h7');
    });

    test('resolves nested maps and lists recursively', () {
      final result = Template.resolve(
        {
          'a': '{{x}}',
          'b': ['{{y}}', 3],
        },
        {'x': 1, 'y': 'z'},
      );
      expect(result, {
        'a': 1,
        'b': ['z', 3],
      });
    });

    test('non-string values pass through unchanged', () {
      expect(Template.resolve(5, {}), 5);
      expect(Template.resolve(true, {}), true);
    });
  });

  group('Template.truthy', () {
    test('null, false, empty, zero and empty collections are false', () {
      for (final value in <Object?>[null, false, '', 'false', '0', 0, [], {}]) {
        expect(Template.truthy(value), isFalse, reason: '$value');
      }
    });

    test('other values are true', () {
      for (final value in <Object?>[
        'yes',
        'abc',
        1,
        true,
        [1],
      ]) {
        expect(Template.truthy(value), isTrue, reason: '$value');
      }
    });
  });
}
