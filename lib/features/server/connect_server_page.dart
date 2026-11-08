import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n.dart';
import '../auth/auth_service.dart';
import '../push/push_service.dart';
import '../startup/brand.dart';
import 'error_messages.dart';
import 'server_session.dart';

/// Asks for the n8n server URL, checks it is an n8n Connect server and links
/// the signed-in account to it.
class ConnectServerPage extends StatefulWidget {
  const ConnectServerPage({super.key});

  @override
  State<ConnectServerPage> createState() => _ConnectServerPageState();
}

class _ConnectServerPageState extends State<ConnectServerPage> {
  late final TextEditingController _url;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = context.read<ServerSession>();
    _url = TextEditingController(text: session.lastUrl ?? '');
    final dropped = session.lastError;
    if (dropped != null) _error = describeError(dropped);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _connecting = true;
      _error = null;
    });
    final session = context.read<ServerSession>();
    final push = context.read<PushService>();
    try {
      await session.connect(_url.text);
      // Pushes are only useful once a server can send them. The FCM token
      // was already registered by the exchange, granted or not.
      try {
        await push.requestPermission();
      } catch (e) {
        // Connected anyway; pushes just won't be shown.
      }
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await context.read<ServerSession>().disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthService>();
    final session = context.watch<ServerSession>();
    final email = auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: context.canPop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTooltip,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const Center(child: BrandMark(size: 72)),
            const SizedBox(height: 20),
            Text(
              l10n.connectTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.connectSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _url,
              enabled: !_connecting,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _connect(),
              decoration: InputDecoration(
                labelText: l10n.connectUrlLabel,
                hintText: 'https://n8n.example.com',
                prefixIcon: const Icon(Icons.dns_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _connecting ? null : _connect,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(l10n.connectButton),
            ),
            if (session.isConnected) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _connecting ? null : _disconnect,
                child: Text(l10n.disconnectButton),
              ),
            ],
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(l10n.connectSignedInAs(email)),
                subtitle: Text(l10n.connectAllowListHint),
                trailing: TextButton(
                  onPressed: _connecting ? null : auth.signOut,
                  child: Text(l10n.logoutButton),
                ),
              ),
            ),
          ],
        ),
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
