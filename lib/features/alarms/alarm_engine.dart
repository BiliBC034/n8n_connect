import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';

import '../../core/json.dart';
import '../../core/log.dart';

/// An alarm scheduled by an n8n app with `schedule_alarm`.
class N8nAlarm {
  const N8nAlarm({
    required this.appId,
    required this.id,
    required this.at,
    required this.label,
    required this.body,
    required this.nativeId,
  });

  /// App that scheduled it and its own id for the alarm (`id` param), so the
  /// app can replace or cancel it later.
  final String appId;
  final String id;
  final DateTime at;
  final String label;
  final String body;

  /// Id used by the alarm plugin.
  final int nativeId;
}

/// The app's own alarms (plugin `alarm`): AlarmManager + foreground service,
/// so they ring with the default alarm sound even when the app is closed or
/// the phone restarted. Unlike `set_alarm` (Clock app), these can be set from
/// the background, which is what lets n8n set them automatically.
///
/// Static because the FCM background isolate uses it too.
class AlarmEngine {
  AlarmEngine._();

  static Future<void>? _init;

  /// Idempotent; call before anything else in every isolate.
  static Future<void> init() => _init ??= Alarm.init();

  /// Stable, positive, non-zero 31-bit id for [appId] + [id].
  static int nativeId(String appId, String id) {
    // FNV-1a: stable across runs and isolates (String.hashCode is not).
    var hash = 0x811c9dc5;
    // Length prefix: ('a/b', 'c') and ('a', 'b/c') must not collide.
    for (final unit in utf8.encode('${appId.length}:$appId/$id')) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final id31 = hash & 0x7fffffff;
    return id31 == 0 ? 1 : id31;
  }

  /// Schedules (or replaces, same [appId] + [id]) an alarm at [at].
  static Future<void> schedule({
    required String appId,
    required String id,
    required DateTime at,
    String? label,
    String? body,
  }) async {
    await init();
    final when = at.toLocal();
    if (!when.isAfter(DateTime.now())) {
      throw ArgumentError('schedule_alarm: time is in the past ($at)');
    }
    final title = label == null || label.isEmpty ? 'n8n' : label;
    final ok = await Alarm.set(
      alarmSettings: AlarmSettings(
        id: nativeId(appId, id),
        dateTime: when,
        // Null = the phone's default alarm sound.
        assetAudioPath: null,
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: false,
        androidFullScreenIntent: true,
        volumeSettings: const VolumeSettings.fixed(volumeEnforced: false),
        notificationSettings: NotificationSettings(
          title: title,
          body: body == null || body.isEmpty ? _hhmm(when) : body,
          stopButton: 'Stop',
        ),
        payload: jsonEncode({'appId': appId, 'id': id, 'label': title}),
      ),
    );
    if (!ok) throw StateError('schedule_alarm: the plugin refused the alarm');
    appLog('Alarms', 'scheduled $appId/$id at $when');
  }

  static Future<void> cancel({
    required String appId,
    required String id,
  }) async {
    await init();
    await Alarm.stop(nativeId(appId, id));
  }

  static Future<List<N8nAlarm>> list() async {
    await init();
    final alarms = await Alarm.getAlarms();
    return alarms.map(_fromSettings).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Alarms ringing while the app is alive (replays the current set on
  /// listen; listeners de-duplicate by [N8nAlarm.nativeId]).
  static Stream<N8nAlarm> get ringing =>
      Alarm.ringing.expand((set) => set.alarms).map(_fromSettings);

  static Future<void> stop(N8nAlarm alarm) => Alarm.stop(alarm.nativeId);

  /// Stops the ringing alarm and schedules it again [by] from now.
  static Future<void> snooze(N8nAlarm alarm, Duration by) async {
    await Alarm.stop(alarm.nativeId);
    await schedule(
      appId: alarm.appId,
      id: alarm.id,
      at: DateTime.now().add(by),
      label: alarm.label,
      body: alarm.body,
    );
  }

  static N8nAlarm _fromSettings(AlarmSettings settings) {
    Map<String, dynamic> meta = const {};
    try {
      meta = asMap(jsonDecode(settings.payload ?? '{}'));
    } on FormatException {
      // Not one of ours: show it with defaults.
    }
    return N8nAlarm(
      appId: asString(meta['appId']) ?? '',
      id: asString(meta['id']) ?? '${settings.id}',
      at: settings.dateTime,
      label: asString(meta['label']) ?? settings.notificationSettings.title,
      body: settings.notificationSettings.body,
      nativeId: settings.id,
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
