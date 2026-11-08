import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/log.dart';

/// Permissions an n8n app can ask for with the `permission` component or the
/// `request_permission` action.
enum DevicePermission {
  /// Location while the app is open.
  location,

  /// Location "all the time": needed for `report` from a push with the app
  /// closed (e.g. the smart alarm asking where the phone is at night).
  locationAlways,

  notifications;

  static DevicePermission? fromName(String? name) => switch (name) {
    'location' => DevicePermission.location,
    'location_always' => DevicePermission.locationAlways,
    'notifications' => DevicePermission.notifications,
    _ => null,
  };
}

enum PermissionState {
  granted,
  denied,

  /// Only fixable from the system settings.
  permanentlyDenied,

  /// E.g. location services switched off.
  unavailable,
}

/// Phone data that n8n can ask for (`report` action, `include` on submits).
/// Static because the FCM background isolate uses it too. Reading never
/// prompts: only [request] does, and only from the UI.
class DeviceContext {
  DeviceContext._();

  static Future<PermissionState> status(DevicePermission permission) async {
    try {
      switch (permission) {
        case DevicePermission.location:
        case DevicePermission.locationAlways:
          final current = await Geolocator.checkPermission();
          return _locationState(
            current,
            always: permission == DevicePermission.locationAlways,
          );
        case DevicePermission.notifications:
          final settings = await FirebaseMessaging.instance
              .getNotificationSettings();
          return settings.authorizationStatus == AuthorizationStatus.authorized
              ? PermissionState.granted
              : settings.authorizationStatus == AuthorizationStatus.denied
              ? PermissionState.permanentlyDenied
              : PermissionState.denied;
      }
    } catch (e) {
      appLog('DeviceContext', 'status($permission) failed: $e');
      return PermissionState.unavailable;
    }
  }

  /// Asks the user. For "all the time" location Android only offers it in the
  /// system settings once "while in use" is granted, so it opens them.
  static Future<PermissionState> request(DevicePermission permission) async {
    switch (permission) {
      case DevicePermission.location:
      case DevicePermission.locationAlways:
        if (!await Geolocator.isLocationServiceEnabled()) {
          await Geolocator.openLocationSettings();
          return PermissionState.unavailable;
        }
        var current = await Geolocator.checkPermission();
        if (current == LocationPermission.denied) {
          current = await Geolocator.requestPermission();
        }
        final always = permission == DevicePermission.locationAlways;
        if (current == LocationPermission.deniedForever ||
            (always && current == LocationPermission.whileInUse)) {
          await Geolocator.openAppSettings();
        }
        return _locationState(
          await Geolocator.checkPermission(),
          always: always,
        );
      case DevicePermission.notifications:
        await FirebaseMessaging.instance.requestPermission();
        return status(permission);
    }
  }

  /// A last known position younger than this is used as is (instant, and
  /// precise enough for "where does the trip start").
  static const Duration recentEnough = Duration(minutes: 15);

  /// `{lat, lng, accuracy, timestamp}` or `{error: permission_denied |
  /// disabled | timeout | unavailable}`. Uses a recent last known position
  /// when there is one; otherwise waits for a fresh fix and, if that takes
  /// too long, falls back to the last known position of any age.
  static Future<Map<String, dynamic>> location({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return {'error': 'disabled'};
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return {'error': 'permission_denied'};
      }
      // Android's LocationManager directly: the Play Services provider may pop
      // a "Location Accuracy" dialog, impossible in the background.
      final last = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: true,
      );
      Position? position;
      if (last != null &&
          DateTime.now().difference(last.timestamp) < recentEnough) {
        position = last;
      } else {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.medium,
              forceLocationManager: true,
              timeLimit: timeout,
            ),
          );
        } catch (e) {
          appLog('DeviceContext', 'no fresh fix: $e');
          position = last;
        }
      }
      if (position == null) return {'error': 'timeout'};
      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toUtc().toIso8601String(),
      };
    } catch (e) {
      // In the background without "all the time" permission Android refuses.
      appLog('DeviceContext', 'location failed: $e');
      return {'error': 'permission_denied'};
    }
  }

  /// Data for the `include` list of a `report` action or a submit. Unknown
  /// names are ignored. Always includes the time zone, which n8n needs to
  /// turn "07:00" into an instant.
  static Future<Map<String, dynamic>> collect(Iterable<String> include) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'timezone': now.timeZoneName,
      'collectedAt': now.toUtc().toIso8601String(),
    };
    if (include.contains('location')) data['location'] = await location();
    return data;
  }

  static PermissionState _locationState(
    LocationPermission permission, {
    required bool always,
  }) => switch (permission) {
    LocationPermission.always => PermissionState.granted,
    LocationPermission.whileInUse =>
      always ? PermissionState.denied : PermissionState.granted,
    LocationPermission.deniedForever => PermissionState.permanentlyDenied,
    LocationPermission.unableToDetermine => PermissionState.unavailable,
    LocationPermission.denied => PermissionState.denied,
  };
}
