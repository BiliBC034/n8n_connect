import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../generated/l10n.dart';
import '../startup/brand.dart';

/// Email/password and Google sign-in. Navigation after signing in is handled
/// by the router, which listens to [AuthService].
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SignInScreen(
      providers: [
        EmailAuthProvider(),
        if (AppConfig.googleClientId.isNotEmpty)
          GoogleProvider(clientId: AppConfig.googleClientId),
      ],
      headerBuilder: (context, constraints, _) => const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(child: BrandMark(size: 72)),
      ),
      subtitleBuilder: (context, action) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l10n.loginSubtitle),
      ),
      footerBuilder: (context, action) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          l10n.loginFooter,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
