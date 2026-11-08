import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/log.dart';
import '../../core/navigation.dart';
import 'alarm_engine.dart';
import 'alarm_ring_page.dart';

/// Opens the ring screen when an n8n alarm goes off while the app is alive.
/// Sits above the Router, so it works on any screen. One ring screen is shown
/// at a time; alarms that ring meanwhile wait their turn.
class AlarmRingListener extends StatefulWidget {
  const AlarmRingListener({super.key, required this.child});

  final Widget child;

  @override
  State<AlarmRingListener> createState() => _AlarmRingListenerState();
}

class _AlarmRingListenerState extends State<AlarmRingListener> {
  StreamSubscription<N8nAlarm>? _ringing;

  /// Native ids of alarms queued or on screen, so one alarm never opens twice.
  final Set<int> _shown = {};
  final List<N8nAlarm> _queue = [];
  bool _onScreen = false;
  bool _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    // The stream replays the alarms already ringing, so this also covers an
    // alarm that went off while the app was closed.
    _ringing = AlarmEngine.ringing.listen(
      _enqueue,
      onError: (Object e) => appLog('Alarms', 'ringing stream failed: $e'),
    );
  }

  @override
  void dispose() {
    _ringing?.cancel();
    _queue.clear();
    super.dispose();
  }

  void _enqueue(N8nAlarm alarm) {
    if (!_shown.add(alarm.nativeId)) return;
    _queue.add(alarm);
    _showNext();
  }

  void _showNext() {
    if (_onScreen || _queue.isEmpty || !mounted) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      // The Router's navigator is built after the first frame.
      if (!_retryScheduled) {
        _retryScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _retryScheduled = false;
          _showNext();
        });
      }
      return;
    }
    final alarm = _queue.removeAt(0);
    _onScreen = true;
    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AlarmRingPage(alarm: alarm),
    );
    unawaited(
      navigator.push<void>(route).then((_) {
        _shown.remove(alarm.nativeId);
        _onScreen = false;
        _showNext();
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
