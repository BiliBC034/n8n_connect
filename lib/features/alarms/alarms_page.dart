import 'package:flutter/material.dart';

import '../../core/log.dart';
import '../../core/navigation.dart';
import '../../generated/l10n.dart';
import 'alarm_engine.dart';

/// Alarms scheduled by n8n apps (`schedule_alarm`), with cancel.
class AlarmsPage extends StatefulWidget {
  const AlarmsPage({super.key});

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> {
  List<N8nAlarm>? _alarms;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final alarms = await AlarmEngine.list();
      if (!mounted) return;
      setState(() {
        _alarms = alarms;
        _failed = false;
      });
    } on Object catch (e) {
      appLog('Alarms', 'list failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _confirmCancel(N8nAlarm alarm) async {
    final l10n = AppLocalizations.of(context);
    final time = TimeOfDay.fromDateTime(alarm.at).format(context);
    final label = alarm.label.isEmpty ? l10n.alarmsDefaultLabel : alarm.label;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.alarmsCancelTitle),
        content: Text(l10n.alarmsCancelMessage(time, label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.dialogActionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.alarmsCancelConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AlarmEngine.cancel(appId: alarm.appId, id: alarm.id);
      showAppSnackBar(l10n.alarmsCancelled);
    } on Object catch (e) {
      appLog('Alarms', 'cancel failed: $e');
      showAppSnackBar(l10n.alarmsCancelFailed, error: true);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alarms = _alarms;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alarmsTitle)),
      body: alarms == null
          ? (_failed
                ? _buildError(l10n)
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: alarms.isEmpty
                    ? [_buildEmpty(context, l10n)]
                    : [
                        for (final alarm in alarms)
                          _AlarmTile(
                            alarm: alarm,
                            onCancel: () => _confirmCancel(alarm),
                          ),
                      ],
              ),
            ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.alarm, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            l10n.alarmsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.alarmsLoadFailed),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            setState(() => _failed = false);
            _load();
          },
          child: Text(l10n.alarmsRetry),
        ),
      ],
    ),
  );
}

/// One alarm: time and date first, then label and the app that set it.
/// Alarms whose time has passed are dimmed.
class _AlarmTile extends StatelessWidget {
  const _AlarmTile({required this.alarm, required this.onCancel});

  final N8nAlarm alarm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final past = alarm.at.isBefore(DateTime.now());
    final time = TimeOfDay.fromDateTime(alarm.at).format(context);
    final date = MaterialLocalizations.of(context).formatMediumDate(alarm.at);
    final label = alarm.label.isEmpty ? l10n.alarmsDefaultLabel : alarm.label;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(date, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(label, style: theme.textTheme.titleMedium),
                    if (alarm.appId.isNotEmpty)
                      Text(l10n.alarmsFromApp(alarm.appId), style: muted),
                    if (past) Text(l10n.alarmsPassed, style: muted),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.alarmsCancelTooltip,
                icon: const Icon(Icons.delete_outline),
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
