import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/json.dart';
import '../../core/log.dart';

/// Text or link another app shared with n8n Connect.
class SharedContent {
  const SharedContent({required this.text, this.subject});

  final String text;
  final String? subject;
}

/// Bridge with MainActivity, which keeps the last `ACTION_SEND` until Dart
/// takes it (cold start) and notifies when a new one arrives while running.
class ShareIntake {
  ShareIntake() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shareReceived') _arrivals.add(null);
    });
  }

  static const MethodChannel _channel = MethodChannel(
    'me.bilibc.n8n_connect/system',
  );

  final StreamController<void> _arrivals = StreamController<void>.broadcast();

  SharedContent? _current;

  /// Content shown on the share screen. Kept here rather than in the route's
  /// `extra`, which go_router drops when it re-parses the location (e.g. on a
  /// `refreshListenable` notification).
  SharedContent? get current => _current;

  void clearCurrent() => _current = null;

  /// Fires when a share arrives while the app is running; call
  /// [takePending] to get it.
  Stream<void> get arrivals => _arrivals.stream;

  /// Returns the pending share once (null if there is none).
  Future<SharedContent?> takePending() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'takeSharedContent',
      );
      final text = asString(raw?['text'])?.trim();
      if (text == null || text.isEmpty) return null;
      return _current = SharedContent(
        text: text,
        subject: asString(raw?['subject']),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      appLog('Share', 'takeSharedContent failed: $e');
      return null;
    }
  }
}
