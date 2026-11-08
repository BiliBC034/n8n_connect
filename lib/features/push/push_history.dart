import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log.dart';
import 'push_payload.dart';

/// What happened with a push from n8n.
enum PushStatus { pending, executed, ignored, failed }

class PushHistoryEntry {
  const PushHistoryEntry({
    required this.payload,
    required this.receivedAt,
    required this.status,
  });

  final PushPayload payload;
  final DateTime receivedAt;
  final PushStatus status;

  Map<String, dynamic> toJson() => {
    'payload': payload.encode(),
    'receivedAt': receivedAt.toIso8601String(),
    'status': status.name,
  };

  /// Returns null for entries that cannot be read back.
  static PushHistoryEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final rawPayload = map['payload'];
    final payload = rawPayload is String
        ? PushPayload.decode(rawPayload)
        : rawPayload is Map
        ? PushPayload.decode(jsonEncode(rawPayload))
        : null;
    final rawDate = map['receivedAt'];
    final receivedAt = rawDate is String ? DateTime.tryParse(rawDate) : null;
    PushStatus? status;
    for (final s in PushStatus.values) {
      if (s.name == map['status']) status = s;
    }
    if (payload == null || receivedAt == null || status == null) return null;
    return PushHistoryEntry(
      payload: payload,
      receivedAt: receivedAt,
      status: status,
    );
  }
}

/// Persistent list of the latest pushes received from n8n (inbox), newest
/// first. Stored in SharedPreferences under [_key].
class PushHistory extends ChangeNotifier {
  static const String _key = 'nc.push.history';

  /// Entries recorded by the FCM background isolate, merged into the inbox
  /// by the UI isolate (each isolate caches SharedPreferences separately).
  static const String _backgroundKey = 'nc.push.background';
  static const int maxEntries = 50;

  /// Records a push handled with the app closed (automations).
  static Future<void> recordFromBackground(
    PushPayload payload,
    PushStatus status,
  ) async {
    try {
      final prefs = SharedPreferencesAsync();
      final pending = await prefs.getStringList(_backgroundKey) ?? <String>[];
      pending.add(
        jsonEncode(
          PushHistoryEntry(
            payload: payload,
            receivedAt: DateTime.now(),
            status: status,
          ).toJson(),
        ),
      );
      await prefs.setStringList(
        _backgroundKey,
        pending.length > maxEntries
            ? pending.sublist(pending.length - maxEntries)
            : pending,
      );
    } catch (e) {
      appLog('Push', 'background entry not saved: $e');
    }
  }

  /// Moves entries recorded in the background into the inbox.
  Future<void> mergeBackground() async {
    await load();
    final List<String> pending;
    try {
      final prefs = SharedPreferencesAsync();
      pending = await prefs.getStringList(_backgroundKey) ?? const [];
      if (pending.isEmpty) return;
      await prefs.remove(_backgroundKey);
    } catch (e) {
      appLog('Push', 'background entries unreadable: $e');
      return;
    }
    for (final raw in pending) {
      try {
        final entry = PushHistoryEntry.fromJson(jsonDecode(raw));
        if (entry == null) continue;
        _entries.removeWhere((e) => e.payload.id == entry.payload.id);
        _entries.insert(0, entry);
      } on FormatException {
        continue;
      }
    }
    _entries.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
    await _save();
  }

  final List<PushHistoryEntry> _entries = [];
  Future<void>? _loading;

  // Writes are chained so the stored list always ends up as the last state.
  Future<void> _writes = Future<void>.value();

  /// Newest first. Starts loading the stored history when first read.
  List<PushHistoryEntry> get entries {
    if (_loading == null) unawaited(load());
    return List.unmodifiable(_entries);
  }

  /// Reads the stored history. Calling it again returns the same future.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored != null && stored.isNotEmpty) {
        final list = jsonDecode(stored);
        if (list is List) {
          for (final item in list) {
            final entry = PushHistoryEntry.fromJson(item);
            if (entry != null) _entries.add(entry);
          }
        }
      }
    } catch (e) {
      // Corrupt or unreadable data: start with an empty inbox.
      appLog('Push', 'history ignored: $e');
      _entries.clear();
    }
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
    // Not awaited inside load(): mergeBackground() awaits load() itself.
    unawaited(mergeBackground());
  }

  /// Adds the push or updates the status of an existing entry (same id).
  /// A known id keeps its position and original receivedAt.
  Future<void> record(PushPayload payload, PushStatus status) async {
    await load();
    final index = _entries.indexWhere((e) => e.payload.id == payload.id);
    if (index >= 0) {
      final old = _entries[index];
      _entries[index] = PushHistoryEntry(
        payload: payload,
        receivedAt: old.receivedAt,
        status: status,
      );
    } else {
      _entries.insert(
        0,
        PushHistoryEntry(
          payload: payload,
          receivedAt: DateTime.now(),
          status: status,
        ),
      );
      if (_entries.length > maxEntries) {
        _entries.removeRange(maxEntries, _entries.length);
      }
    }
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    await load();
    _entries.clear();
    notifyListeners();
    await _save();
  }

  Future<void> _save() {
    final snapshot = jsonEncode([for (final e in _entries) e.toJson()]);
    return _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, snapshot);
      } catch (e) {
        appLog('Push', 'history not saved: $e');
      }
    });
  }
}
