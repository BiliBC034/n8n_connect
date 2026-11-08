import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device capabilities n8n can trigger. Android only for now: each one opens
/// the system app through a standard intent, so no special permission beyond
/// `SET_ALARM` (declared in the manifest) is required. `launch_app` uses the
/// package's own launcher intent through MainActivity, which can see other
/// apps thanks to the MAIN/LAUNCHER `<queries>` entry in the manifest.
class DeviceActions {
  static const MethodChannel _system = MethodChannel(
    'me.bilibc.n8n_connect/system',
  );

  /// Creates an alarm in the Clock app (AlarmClock.ACTION_SET_ALARM).
  /// [days] uses java.util.Calendar numbering: 1 = Sunday … 7 = Saturday.
  Future<void> setAlarm({
    required int hour,
    required int minute,
    String? label,
    List<int>? days,
    bool? vibrate,
    bool skipUi = true,
  }) async {
    _requireAndroid();
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('hour/minute out of range: $hour:$minute');
    }
    await AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        if (label != null && label.isNotEmpty)
          'android.intent.extra.alarm.MESSAGE': label,
        if (days != null && days.isNotEmpty)
          'android.intent.extra.alarm.DAYS': days,
        if (vibrate != null) 'android.intent.extra.alarm.VIBRATE': vibrate,
        'android.intent.extra.alarm.SKIP_UI': skipUi,
      },
    ).launch();
  }

  /// Starts a countdown in the Clock app (AlarmClock.ACTION_SET_TIMER).
  Future<void> setTimer({
    required int seconds,
    String? label,
    bool skipUi = true,
  }) async {
    _requireAndroid();
    if (seconds < 1 || seconds > 86400) {
      throw ArgumentError('timer seconds out of range: $seconds');
    }
    await AndroidIntent(
      action: 'android.intent.action.SET_TIMER',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.LENGTH': seconds,
        if (label != null && label.isNotEmpty)
          'android.intent.extra.alarm.MESSAGE': label,
        'android.intent.extra.alarm.SKIP_UI': skipUi,
      },
    ).launch();
  }

  /// Opens the calendar's "new event" screen prefilled.
  Future<void> addCalendarEvent({
    required String title,
    required DateTime start,
    DateTime? end,
    String? location,
    String? description,
    bool allDay = false,
  }) async {
    _requireAndroid();
    await AndroidIntent(
      action: 'android.intent.action.INSERT',
      data: 'content://com.android.calendar/events',
      arguments: <String, dynamic>{
        'title': title,
        'beginTime': start.millisecondsSinceEpoch,
        'endTime':
            (end ?? start.add(const Duration(hours: 1))).millisecondsSinceEpoch,
        'allDay': allDay,
        if (location != null && location.isNotEmpty) 'eventLocation': location,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    ).launch();
  }

  static const Set<String> allowedUrlSchemes = {
    'https',
    'http',
    'mailto',
    'tel',
    'geo',
  };

  Future<void> openUrl(Uri url) async {
    _requireAndroid();
    if (!allowedUrlSchemes.contains(url.scheme)) {
      throw ArgumentError('URL scheme not allowed: ${url.scheme}');
    }
    await AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: url.toString(),
    ).launch();
  }

  /// Share sheet for plain text, through the system chooser.
  Future<void> share({
    required String text,
    String? subject,
    required String chooserTitle,
  }) async {
    _requireAndroid();
    await AndroidIntent(
      action: 'android.intent.action.SEND',
      type: 'text/plain',
      arguments: <String, dynamic>{
        'android.intent.extra.TEXT': text,
        if (subject != null && subject.isNotEmpty)
          'android.intent.extra.SUBJECT': subject,
      },
    ).launchChooser(chooserTitle);
  }

  /// Opens the dialer with [number] filled in. Never places the call.
  Future<void> dial(String number) async {
    _requireAndroid();
    await AndroidIntent(
      action: 'android.intent.action.DIAL',
      data: buildTelUri(number),
    ).launch();
  }

  /// Opens the messaging app with a new text to [number].
  Future<void> sms(String number, {String? body}) async {
    _requireAndroid();
    await AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: buildSmsUri(number),
      arguments: <String, dynamic>{
        if (body != null && body.isNotEmpty) 'sms_body': body,
      },
    ).launch();
  }

  /// Opens the mail app with a new message.
  Future<void> email({
    required String to,
    String? subject,
    String? body,
  }) async {
    _requireAndroid();
    await AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: buildMailtoUri(to, subject: subject, body: body),
    ).launch();
  }

  /// Opens a map place, or starts navigation to it when [navigate] is true.
  Future<void> openMaps({
    String? query,
    double? lat,
    double? lng,
    String? label,
    bool navigate = false,
  }) async {
    _requireAndroid();
    await AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: buildMapsUri(
        query: query,
        lat: lat,
        lng: lng,
        label: label,
        navigate: navigate,
      ),
    ).launch();
  }

  /// Opens the Clock app's alarm list.
  Future<void> showAlarms() async {
    _requireAndroid();
    await AndroidIntent(action: 'android.intent.action.SHOW_ALARMS').launch();
  }

  /// Haptic feedback: `light`, `medium`, `heavy` or `vibrate` (the default
  /// when [style] is null or empty).
  Future<void> vibrate({String? style}) async {
    switch (style?.trim().toLowerCase() ?? '') {
      case '':
      case 'vibrate':
        await HapticFeedback.vibrate();
      case 'light':
        await HapticFeedback.lightImpact();
      case 'medium':
        await HapticFeedback.mediumImpact();
      case 'heavy':
        await HapticFeedback.heavyImpact();
      default:
        throw ArgumentError('vibrate: unknown style $style');
    }
  }

  /// Opens one of the system settings screens named in [settingsActionFor].
  Future<void> openSettings(String panel) async {
    _requireAndroid();
    final action = settingsActionFor(panel);
    if (action == null) {
      throw ArgumentError('open_settings: unknown panel $panel');
    }
    final name = panel.trim().toLowerCase();
    String? data;
    Map<String, dynamic>? arguments;
    if (name == 'app' || name == 'notifications') {
      final package = (await PackageInfo.fromPlatform()).packageName;
      if (name == 'app') data = 'package:$package';
      if (name == 'notifications') {
        arguments = {'android.provider.extra.APP_PACKAGE': package};
      }
    }
    await AndroidIntent(
      action: action,
      data: data,
      arguments: arguments,
    ).launch();
  }

  /// Opens the launcher screen of another app by its package name.
  Future<void> launchApp(String package) async {
    _requireAndroid();
    if (!isValidPackageName(package)) {
      throw ArgumentError('launch_app: invalid package $package');
    }
    final launched = await _system.invokeMethod<bool>('launchApp', {
      'package': package,
    });
    if (launched != true) {
      throw PlatformException(code: 'not_installed', message: package);
    }
  }

  /// Sends the app to the background (used after running an action from a
  /// notification button, so the user lands back where they were).
  Future<void> moveToBackground() async {
    if (!Platform.isAndroid) return;
    try {
      await _system.invokeMethod<bool>('moveTaskToBack');
    } on PlatformException {
      // Not critical.
    }
  }

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Device actions are only available on Android');
    }
  }
}

/// `tel:` URI for the dialer. The number is percent-encoded.
String buildTelUri(String number) =>
    'tel:${Uri.encodeComponent(number.trim())}';

/// `smsto:` URI for the messaging app.
String buildSmsUri(String number) =>
    'smsto:${Uri.encodeComponent(number.trim())}';

/// `mailto:` URI with optional subject and body. Spaces become %20 (not +);
/// empty parts are left out. The address keeps its `@` and commas readable.
String buildMailtoUri(String to, {String? subject, String? body}) {
  final parts = <String>[
    if (subject != null && subject.isNotEmpty)
      'subject=${Uri.encodeComponent(subject)}',
    if (body != null && body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
  ];
  final address = Uri.encodeComponent(
    to.trim(),
  ).replaceAll('%40', '@').replaceAll('%2C', ',');
  return 'mailto:$address${parts.isEmpty ? '' : '?${parts.join('&')}'}';
}

/// Map URI for a place given by [query], or by [lat] and [lng] with an
/// optional [label] (the pin name). With [navigate] the URI starts turn by
/// turn navigation. [query] wins over the coordinates when both are given.
/// Throws [ArgumentError] when there is neither a query nor lat and lng.
String buildMapsUri({
  String? query,
  double? lat,
  double? lng,
  String? label,
  bool navigate = false,
}) {
  final text = (query ?? '').trim();
  if (text.isNotEmpty) {
    if (navigate) {
      return 'google.navigation:q=${Uri.encodeComponent(text)}';
    }
    return 'geo:0,0?q=${Uri.encodeComponent(text)}';
  }
  if (lat == null || lng == null) {
    throw ArgumentError('maps: missing query or lat/lng');
  }
  if (!(lat >= -90 && lat <= 90) || !(lng >= -180 && lng <= 180)) {
    throw ArgumentError('maps: lat/lng out of range: $lat,$lng');
  }
  final coords = '$lat,$lng';
  if (navigate) {
    return 'google.navigation:q=${Uri.encodeComponent(coords)}';
  }
  final name = label == null || label.isEmpty
      ? ''
      : '(${Uri.encodeComponent(label)})';
  return 'geo:$coords?q=$coords$name';
}

/// Intent actions of the settings screens n8n can open (`open_settings`).
const Map<String, String> _settingsActions = {
  'wifi': 'android.settings.WIFI_SETTINGS',
  'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
  'location': 'android.settings.LOCATION_SOURCE_SETTINGS',
  'display': 'android.settings.DISPLAY_SETTINGS',
  'sound': 'android.settings.SOUND_SETTINGS',
  'battery': 'android.settings.BATTERY_SAVER_SETTINGS',
  'date': 'android.settings.DATE_SETTINGS',
  'notifications': 'android.settings.APP_NOTIFICATION_SETTINGS',
  'app': 'android.settings.APPLICATION_DETAILS_SETTINGS',
};

/// Intent action of the settings screen for [panel] (case-insensitive), or
/// null when the panel is unknown.
String? settingsActionFor(String panel) =>
    _settingsActions[panel.trim().toLowerCase()];

final RegExp _packageName = RegExp(
  r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
);

/// True for an Android application id such as `com.whatsapp`: at least two
/// dot-separated segments, each starting with a letter.
bool isValidPackageName(String value) => _packageName.hasMatch(value);
