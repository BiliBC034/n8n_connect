import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n.dart';
import '../server/server_session.dart';
import 'automation_consent.dart';

/// `automation` component: lets the user allow this app to run actions
/// (alarms, location reports…) on the phone without asking each time.
class AutomationSwitch extends StatefulWidget {
  const AutomationSwitch({
    super.key,
    required this.appId,
    this.label = '',
    this.description = '',
  });

  final String appId;
  final String label;
  final String description;

  @override
  State<AutomationSwitch> createState() => _AutomationSwitchState();
}

class _AutomationSwitchState extends State<AutomationSwitch> {
  bool? _allowed;

  Uri? get _server => context.read<ServerSession>().baseUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final server = _server;
    final allowed = server == null
        ? false
        : await AutomationConsent.isAllowed(server, widget.appId);
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _set(bool value) async {
    final server = _server;
    if (server == null) return;
    await AutomationConsent.setAllowed(server, widget.appId, value);
    if (mounted) setState(() => _allowed = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allowed = _allowed;
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: const Icon(Icons.bolt),
        title: Text(widget.label.isEmpty ? l10n.automationTitle : widget.label),
        subtitle: Text(
          widget.description.isEmpty
              ? l10n.automationDescription
              : widget.description,
        ),
        value: allowed ?? false,
        onChanged: allowed == null ? null : _set,
      ),
    );
  }
}
