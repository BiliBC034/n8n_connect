import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/log.dart';
import '../../generated/l10n.dart';
import 'alarm_engine.dart';

/// Full-screen screen for an n8n alarm that rings while the app is open.
/// Back does not dismiss it: the alarm keeps ringing until Stop or Snooze.
class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({super.key, required this.alarm});

  final N8nAlarm alarm;

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  Timer? _clock;
  DateTime _now = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _stop() => _finish(() => AlarmEngine.stop(widget.alarm));

  Future<void> _snooze() => _finish(
    () => AlarmEngine.snooze(widget.alarm, const Duration(minutes: 5)),
  );

  Future<void> _finish(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      appLog('Alarms', 'ring action failed: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onColor = scheme.onPrimaryContainer;
    final alarm = widget.alarm;
    final time = TimeOfDay.fromDateTime(_now).format(context);
    final label = alarm.label.isEmpty ? l10n.alarmsDefaultLabel : alarm.label;
    // The engine fills in the time as body when none was given; that repeats
    // the big clock, so it is only shown when it says something else.
    final alarmHhmm =
        '${alarm.at.hour.toString().padLeft(2, '0')}:'
        '${alarm.at.minute.toString().padLeft(2, '0')}';
    final showBody = alarm.body.isNotEmpty && alarm.body != alarmHhmm;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.primaryContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.alarm, size: 48, color: onColor),
                const SizedBox(height: 16),
                Text(
                  time,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: onColor,
                  ),
                ),
                if (showBody) ...[
                  const SizedBox(height: 8),
                  Text(
                    alarm.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: onColor),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    onPressed: _busy ? null : _stop,
                    child: Text(
                      l10n.alarmsStop,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _snooze,
                    child: Text(
                      l10n.alarmsSnooze,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
