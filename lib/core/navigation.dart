import 'package:flutter/material.dart';

/// Root navigator, used by services that need to show dialogs (push actions,
/// confirmations) without a widget context of their own.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Root scaffold messenger, so snack bars survive route changes.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Context below the root navigator's overlay: has Navigator, Localizations
/// and Theme above it. Null until the first frame is built.
BuildContext? get rootOverlayContext =>
    rootNavigatorKey.currentState?.overlay?.context;

void showAppSnackBar(String message, {bool error = false}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  final colors = Theme.of(messenger.context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? colors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
