import 'package:flutter/material.dart';

import '../../core/log.dart';
import '../../generated/l10n.dart';
import 'device_context.dart';

/// `permission` component: shows whether a permission is granted and lets
/// the user grant it. Re-reads the state on init and every time the app
/// comes back to the foreground (the user may have changed it in settings).
class PermissionTile extends StatefulWidget {
  const PermissionTile({
    super.key,
    required this.permission,
    this.label = '',
    this.description = '',
  });

  final DevicePermission permission;
  final String label;
  final String description;

  @override
  State<PermissionTile> createState() => _PermissionTileState();
}

class _PermissionTileState extends State<PermissionTile>
    with WidgetsBindingObserver {
  /// Null until the first read finishes.
  PermissionState? _state;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final state = await DeviceContext.status(widget.permission);
    if (mounted) setState(() => _state = state);
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      await DeviceContext.request(widget.permission);
    } catch (e) {
      appLog('PermissionTile', 'request(${widget.permission}) failed: $e');
    }
    await _refresh();
    if (mounted) setState(() => _requesting = false);
  }

  IconData get _icon => switch (widget.permission) {
    DevicePermission.location ||
    DevicePermission.locationAlways => Icons.location_on,
    DevicePermission.notifications => Icons.notifications,
  };

  String _defaultTitle(AppLocalizations l10n) => switch (widget.permission) {
    DevicePermission.location => l10n.permLocationTitle,
    DevicePermission.locationAlways => l10n.permLocationAlwaysTitle,
    DevicePermission.notifications => l10n.permNotificationsTitle,
  };

  String _defaultDescription(AppLocalizations l10n) =>
      switch (widget.permission) {
        DevicePermission.location => l10n.permLocationDescription,
        DevicePermission.locationAlways => l10n.permLocationAlwaysDescription,
        DevicePermission.notifications => l10n.permNotificationsDescription,
      };

  Widget? _trailing(AppLocalizations l10n) {
    if (_requesting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return switch (_state) {
      null => null,
      PermissionState.granted => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 4),
          Text(l10n.permGranted),
        ],
      ),
      PermissionState.unavailable => Text(
        l10n.permUnavailable,
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
      PermissionState.denied => FilledButton.tonal(
        onPressed: _request,
        child: Text(l10n.permGrant),
      ),
      PermissionState.permanentlyDenied => FilledButton.tonal(
        onPressed: _request,
        child: Text(l10n.permOpenSettings),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(_icon),
        title: Text(widget.label.isEmpty ? _defaultTitle(l10n) : widget.label),
        subtitle: Text(
          widget.description.isEmpty
              ? _defaultDescription(l10n)
              : widget.description,
        ),
        trailing: _trailing(l10n),
      ),
    );
  }
}
