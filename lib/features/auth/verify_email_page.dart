import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_service.dart';

/// Sends the verification email and waits for the user to confirm it. The n8n
/// server rejects unverified emails, so this step cannot be skipped.
class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return EmailVerificationScreen(
      actions: [
        EmailVerifiedAction(auth.reloadUser),
        AuthCancelledAction((_) => auth.signOut()),
      ],
    );
  }
}
