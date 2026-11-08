import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/actions/action_executor.dart';
import 'package:n8n_connect/features/actions/action_spec.dart';
import 'package:n8n_connect/features/actions/device_actions.dart';
import 'package:n8n_connect/generated/l10n.dart';

void main() {
  setUp(() async => AppLocalizations.load(const Locale('en')));

  group('buildTelUri and buildSmsUri', () {
    test('encode the number', () {
      expect(buildTelUri('+34 600123123'), 'tel:%2B34%20600123123');
      expect(buildSmsUri(' 600123123 '), 'smsto:600123123');
    });
  });

  group('buildMailtoUri', () {
    test('address only', () {
      expect(buildMailtoUri('a@b.com'), 'mailto:a@b.com');
    });

    test('spaces become %20, not +', () {
      expect(
        buildMailtoUri('a@b.com', subject: 'Hello world'),
        'mailto:a@b.com?subject=Hello%20world',
      );
    });

    test('empty subject and body are omitted', () {
      expect(
        buildMailtoUri('a@b.com', subject: '', body: ''),
        'mailto:a@b.com',
      );
      expect(buildMailtoUri('a@b.com', body: 'Hi'), 'mailto:a@b.com?body=Hi');
    });

    test('subject and body are joined with &', () {
      expect(
        buildMailtoUri('a@b.com', subject: 'Hi', body: 'How are you'),
        'mailto:a@b.com?subject=Hi&body=How%20are%20you',
      );
    });

    test('special characters are percent-encoded', () {
      expect(
        buildMailtoUri('a@b.com', subject: 'a+b&c=d?'),
        'mailto:a@b.com?subject=a%2Bb%26c%3Dd%3F',
      );
      expect(
        buildMailtoUri('a@b.com', body: 'Línea 1\nA&B'),
        'mailto:a@b.com?body=L%C3%ADnea%201%0AA%26B',
      );
    });
  });

  group('buildMapsUri', () {
    test('query opens a place', () {
      expect(buildMapsUri(query: 'Madrid Centro'), 'geo:0,0?q=Madrid%20Centro');
    });

    test('coordinates open a pin', () {
      expect(buildMapsUri(lat: 40.4, lng: -3.7), 'geo:40.4,-3.7?q=40.4,-3.7');
    });

    test('label is added to the pin', () {
      expect(
        buildMapsUri(lat: 40.4, lng: -3.7, label: 'Ana House'),
        'geo:40.4,-3.7?q=40.4,-3.7(Ana%20House)',
      );
    });

    test('navigate uses google.navigation with the query or coordinates', () {
      expect(
        buildMapsUri(query: 'Calle Mayor 1', navigate: true),
        'google.navigation:q=Calle%20Mayor%201',
      );
      expect(
        buildMapsUri(lat: 40.4, lng: -3.7, navigate: true),
        'google.navigation:q=40.4%2C-3.7',
      );
    });

    test('query wins over coordinates', () {
      expect(buildMapsUri(query: 'x', lat: 1, lng: 2), 'geo:0,0?q=x');
    });

    test('missing query and coordinates throws', () {
      expect(() => buildMapsUri(), throwsArgumentError);
      expect(() => buildMapsUri(query: '  '), throwsArgumentError);
      expect(() => buildMapsUri(lat: 1), throwsArgumentError);
      expect(() => buildMapsUri(lng: 1, navigate: true), throwsArgumentError);
    });

    test('coordinates out of range throw', () {
      expect(() => buildMapsUri(lat: 91, lng: 0), throwsArgumentError);
      expect(() => buildMapsUri(lat: 0, lng: -181), throwsArgumentError);
    });
  });

  group('settingsActionFor', () {
    test('every panel maps to its settings action', () {
      expect(settingsActionFor('wifi'), 'android.settings.WIFI_SETTINGS');
      expect(
        settingsActionFor('bluetooth'),
        'android.settings.BLUETOOTH_SETTINGS',
      );
      expect(
        settingsActionFor('location'),
        'android.settings.LOCATION_SOURCE_SETTINGS',
      );
      expect(settingsActionFor('display'), 'android.settings.DISPLAY_SETTINGS');
      expect(settingsActionFor('sound'), 'android.settings.SOUND_SETTINGS');
      expect(
        settingsActionFor('battery'),
        'android.settings.BATTERY_SAVER_SETTINGS',
      );
      expect(settingsActionFor('date'), 'android.settings.DATE_SETTINGS');
      expect(
        settingsActionFor('notifications'),
        'android.settings.APP_NOTIFICATION_SETTINGS',
      );
      expect(
        settingsActionFor('app'),
        'android.settings.APPLICATION_DETAILS_SETTINGS',
      );
    });

    test('is case-insensitive and ignores spaces', () {
      expect(settingsActionFor(' WiFi '), 'android.settings.WIFI_SETTINGS');
    });

    test('unknown panel gives null', () {
      expect(settingsActionFor('camera'), isNull);
      expect(settingsActionFor(''), isNull);
    });
  });

  group('isValidPackageName', () {
    test('accepts application ids', () {
      expect(isValidPackageName('com.whatsapp'), isTrue);
      expect(isValidPackageName('org.mozilla.firefox'), isTrue);
      expect(isValidPackageName('com.my_app.v2'), isTrue);
    });

    test('rejects anything else', () {
      expect(isValidPackageName('whatsapp'), isFalse);
      expect(isValidPackageName('1com.x'), isFalse);
      expect(isValidPackageName('com..x'), isFalse);
      expect(isValidPackageName('com.x;rm'), isFalse);
      expect(isValidPackageName(''), isFalse);
    });
  });

  group('describeAction for device intents', () {
    String describe(String type, [Map<String, dynamic> params = const {}]) =>
        describeAction(ActionSpec(type: type, params: params));

    test('share', () {
      expect(describe('share', {'text': 'Hi'}), 'Share text: Hi');
    });

    test('dial', () {
      expect(
        describe('dial', {'number': '600123123'}),
        'Open the dialer with 600123123',
      );
    });

    test('sms', () {
      expect(
        describe('sms', {'number': '600123123'}),
        'Write a text message to 600123123',
      );
    });

    test('email', () {
      expect(describe('email', {'to': 'a@b.com'}), 'Write an email to a@b.com');
    });

    test('maps with a query, with navigation and with coordinates', () {
      expect(describe('maps', {'query': 'Madrid'}), 'Open Madrid in Maps');
      expect(
        describe('maps', {'query': 'Madrid', 'navigate': true}),
        'Navigate to Madrid',
      );
      expect(
        describe('maps', {'lat': 40.4, 'lng': -3.7}),
        'Open 40.4,-3.7 in Maps',
      );
    });

    test('vibrate', () {
      expect(describe('vibrate', {'style': 'heavy'}), 'Vibrate the phone');
    });

    test('show_alarms', () {
      expect(describe('show_alarms'), 'Show alarms in the Clock app');
    });

    test('open_settings', () {
      expect(
        describe('open_settings', {'panel': 'wifi'}),
        'Open wifi settings',
      );
    });

    test('launch_app', () {
      expect(
        describe('launch_app', {'package': 'com.whatsapp'}),
        'Launch the app com.whatsapp',
      );
    });

    test('read_clipboard', () {
      expect(
        describe('read_clipboard', {'key': 'name'}),
        'Read the clipboard into name',
      );
    });
  });
}
