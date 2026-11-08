import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/log.dart';
import '../../core/navigation.dart';
import '../../generated/l10n.dart';
import '../actions/action_executor.dart';
import '../apps/app_models.dart';
import '../server/error_messages.dart';
import '../server/server_session.dart';
import 'share_intake.dart';

/// Reviews shared content and sends it to `n8n-connect/share`.
class SharePage extends StatefulWidget {
  const SharePage({super.key, this.content});

  /// Content to show; defaults to [ShareIntake.current].
  final SharedContent? content;

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final TextEditingController _note = TextEditingController();
  bool _sending = false;
  String? _error;
  late final SharedContent? _content;

  @override
  void initState() {
    super.initState();
    _content = widget.content ?? context.read<ShareIntake>().current;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(SharedContent content) async {
    final l10n = AppLocalizations.of(context);
    final session = context.read<ServerSession>();
    final executor = context.read<ActionExecutor>();
    setState(() {
      _sending = true;
      _error = null;
    });

    final ActionResponse response;
    try {
      final json = await session.request(
        'POST',
        AppConfig.sharePath,
        body: {
          'text': content.text,
          'subject': content.subject ?? '',
          'note': _note.text.trim(),
        },
      );
      response = ActionResponse.fromJson(json);
    } catch (e) {
      appLog('Share', 'send failed: $e');
      if (mounted) {
        setState(() {
          _sending = false;
          _error = describeError(e);
        });
      }
      return;
    }

    final message = response.message;
    showAppSnackBar(
      message != null && message.isNotEmpty ? message : l10n.shareSent,
    );
    if (mounted) context.read<ShareIntake>().clearCurrent();
    // Runs even if the user left the page meanwhile: n8n asked for it.
    await executor.run(response.actions);
    if (mounted) _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = _content;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shareTitle)),
      body: content == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.shareNothingToShare,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (content.subject case final subject?
                            when subject.isNotEmpty) ...[
                          Text(
                            subject,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                        ],
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: SingleChildScrollView(
                            child: SelectableText(content.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  enabled: !_sending,
                  minLines: 2,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: l10n.shareNoteLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.shareSendHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorCard(message: _error!),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _sending ? null : () => _send(content),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(l10n.shareSendButton),
                ),
              ],
            ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
