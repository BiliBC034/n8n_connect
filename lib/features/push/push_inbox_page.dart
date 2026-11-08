import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n.dart';
import '../actions/action_executor.dart';
import 'push_history.dart';

/// History of pushes from n8n with their status; lets the user re-run them.
class PushInboxPage extends StatefulWidget {
  const PushInboxPage({super.key});

  @override
  State<PushInboxPage> createState() => _PushInboxPageState();
}

class _PushInboxPageState extends State<PushInboxPage> {
  // Ids of the pushes whose actions are running, to avoid double runs.
  final Set<String> _running = <String>{};

  Future<void> _run(PushHistoryEntry entry) async {
    final executor = context.read<ActionExecutor>();
    final history = context.read<PushHistory>();
    final id = entry.payload.id;
    setState(() => _running.add(id));
    try {
      final ok = await executor.run(
        entry.payload.actions,
        appId: entry.payload.appId,
      );
      await history.record(
        entry.payload,
        ok ? PushStatus.executed : PushStatus.failed,
      );
    } finally {
      if (mounted) setState(() => _running.remove(id));
    }
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context);
    final history = context.read<PushHistory>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inboxClearTitle),
        content: Text(l10n.inboxClearMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.dialogActionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.inboxClearConfirm),
          ),
        ],
      ),
    );
    if (ok == true) await history.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = context.watch<PushHistory>().entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inboxTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.inboxClearTooltip,
            onPressed: entries.isEmpty ? null : _confirmClear,
          ),
        ],
      ),
      body: entries.isEmpty
          ? _EmptyInbox(l10n: l10n)
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _PushTile(
                  entry: entry,
                  running: _running.contains(entry.payload.id),
                  onRun: () => _run(entry),
                );
              },
            ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.inboxEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.inboxEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushTile extends StatelessWidget {
  const _PushTile({
    required this.entry,
    required this.running,
    required this.onRun,
  });

  final PushHistoryEntry entry;
  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final payload = entry.payload;
    final actions = payload.actions;
    final receivedAt = entry.receivedAt;
    final when =
        '${MaterialLocalizations.of(context).formatShortDate(receivedAt)} '
        '${TimeOfDay.fromDateTime(receivedAt).format(context)}';

    final (IconData icon, Color color, String label) = switch (entry.status) {
      PushStatus.pending => (
        Icons.schedule,
        colors.onSurfaceVariant,
        l10n.inboxStatusPending,
      ),
      PushStatus.executed => (
        Icons.check_circle,
        colors.primary,
        l10n.inboxStatusExecuted,
      ),
      PushStatus.ignored => (
        Icons.do_not_disturb_on,
        colors.onSurfaceVariant,
        l10n.inboxStatusIgnored,
      ),
      PushStatus.failed => (Icons.error, colors.error, l10n.inboxStatusFailed),
    };

    return ListTile(
      leading: Tooltip(
        message: label,
        child: Icon(icon, color: color),
      ),
      title: Text(payload.title.isEmpty ? l10n.inboxUntitled : payload.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (payload.body.isNotEmpty) Text(payload.body),
          for (final action in actions) Text('• ${describeAction(action)}'),
          const SizedBox(height: 2),
          Text(
            when,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: actions.isEmpty
          ? null
          : TextButton(
              onPressed: running ? null : onRun,
              child: Text(l10n.inboxRun),
            ),
    );
  }
}
