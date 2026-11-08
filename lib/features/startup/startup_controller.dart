import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/log.dart';
import '../alarms/alarm_engine.dart';
import '../push/push_service.dart';
import '../server/server_session.dart';

/// Async initialisation done behind the splash screen.
class StartupController extends ChangeNotifier {
  StartupController({required ServerSession session, required PushService push})
    : _session = session,
      _push = push;

  final ServerSession _session;
  final PushService _push;
  final Completer<void> _done = Completer<void>();

  bool _ready = false;

  bool get ready => _ready;

  /// Completes once the app is ready (push events wait for it).
  Future<void> get done => _done.future;

  Future<void> start() async {
    try {
      await _session.restore();
    } catch (e) {
      appLog('Startup', 'session restore failed: $e');
    }
    try {
      await AlarmEngine.init();
    } catch (e) {
      appLog('Startup', 'alarm engine init failed: $e');
    }
    try {
      _push.onTokenChanged = _session.onPushTokenChanged;
      await _push.init();
    } catch (e) {
      // The app works without push (e.g. no Google Play services).
      appLog('Startup', 'push init failed: $e');
    }
    _ready = true;
    if (!_done.isCompleted) _done.complete();
    notifyListeners();
  }
}
