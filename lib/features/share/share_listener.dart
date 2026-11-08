import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../server/server_session.dart';
import '../startup/startup_controller.dart';
import 'share_intake.dart';

/// Opens the share screen when another app shares text with n8n Connect.
/// Content that arrives before the server is connected waits in memory and
/// opens as soon as the session is up.
class ShareListener extends StatefulWidget {
  const ShareListener({super.key, required this.child});

  final Widget child;

  @override
  State<ShareListener> createState() => _ShareListenerState();
}

class _ShareListenerState extends State<ShareListener> {
  StreamSubscription<void>? _arrivals;
  ServerSession? _session;

  /// Latest share not shown yet. Cleared when the screen opens, so the same
  /// content never opens twice.
  SharedContent? _pending;
  bool _waitingForRoute = false;

  @override
  void initState() {
    super.initState();
    final intake = context.read<ShareIntake>();
    _arrivals = intake.arrivals.listen((_) => _take());
    _session = context.read<ServerSession>()..addListener(_open);
    context.read<StartupController>().done.then((_) {
      if (mounted) _take();
    });
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    _session?.removeListener(_open);
    super.dispose();
  }

  Future<void> _take() async {
    final intake = context.read<ShareIntake>();
    final content = await intake.takePending();
    if (!mounted || content == null) return;
    _pending = content;
    _open();
  }

  void _open() {
    final content = _pending;
    final session = _session;
    if (!mounted || content == null || session == null) return;
    if (!session.isConnected) return;

    // This widget sits above the Router, so it needs the navigator's context.
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      // The router is not mounted yet: retry after the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
      return;
    }
    // Right after connecting, the connect screen replaces the whole stack
    // with the home page: wait for that before opening the share screen.
    final router = GoRouter.of(navContext);
    final delegate = router.routerDelegate;
    if (delegate.currentConfiguration.uri.path == '/connect') {
      if (!_waitingForRoute) {
        _waitingForRoute = true;
        void retry() {
          if (delegate.currentConfiguration.uri.path == '/connect') return;
          delegate.removeListener(retry);
          _waitingForRoute = false;
          _open();
        }

        delegate.addListener(retry);
      }
      return;
    }
    _pending = null;
    router.push('/share');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
