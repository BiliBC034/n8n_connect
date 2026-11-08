import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'session_store.dart';

/// What the app tells the server about this device (stored in nc_devices).
class DeviceIdentity {
  const DeviceIdentity({
    required this.id,
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  final String id;
  final String name;
  final String platform;
  final String appVersion;

  Map<String, dynamic> toJson({String? fcmToken}) => {
    'id': id,
    'name': name,
    'platform': platform,
    'appVersion': appVersion,
    'fcmToken': fcmToken ?? '',
  };

  static Future<DeviceIdentity> load(SessionStore store) async {
    final id = await store.deviceId();
    var name = Platform.operatingSystem;
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        name = '${info.manufacturer} ${info.model}';
      }
    } catch (_) {
      // Keep the generic name.
    }
    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Unknown version is fine.
    }
    return DeviceIdentity(
      id: id,
      name: name,
      platform: Platform.operatingSystem,
      appVersion: version,
    );
  }
}
