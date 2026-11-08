import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/log.dart';

/// Firebase identity of the app user. Notifies on sign in/out and on profile
/// changes (e.g. the email becoming verified), which drives the router.
class AuthService extends ChangeNotifier {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn() {
    _subscription = _auth.userChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  late final StreamSubscription<User?> _subscription;

  User? get currentUser => _auth.currentUser;

  // Kept for the settings page.
  User? getCurrentUser() => _auth.currentUser;

  /// Email/password accounts must verify their address before the n8n server
  /// accepts them (the server checks `emailVerified` too).
  bool get needsEmailVerification {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return false;
    return user.providerData.any(
      (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
    );
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) await _googleSignIn.signOut();
    } catch (e) {
      appLog('Auth', 'Google sign out failed: $e');
    }
    await _auth.signOut();
  }

  Future<String?> updateUserDisplayName(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in.';
      await user.updateDisplayName(name);
      await user.reload();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to update display name.';
    } catch (e) {
      appLog('Auth', 'updateDisplayName: $e');
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> _reauthenticateEmailPasswordUser(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'User not found or email is null.';
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Re-authentication failed.';
    } catch (e) {
      appLog('Auth', 'reauthenticate: $e');
      return 'An unexpected error occurred during re-authentication.';
    }
  }

  Future<String?> updateUserPassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return 'No user logged in.';
    final reauthError = await _reauthenticateEmailPasswordUser(currentPassword);
    if (reauthError != null) return 'Re-authentication failed: $reauthError';
    try {
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to update password.';
    } catch (e) {
      appLog('Auth', 'updatePassword: $e');
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> deleteUserAccount({String? currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null) return 'No user logged in.';

    final isEmailProvider = user.providerData.any(
      (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    if (isEmailProvider &&
        currentPassword != null &&
        currentPassword.isNotEmpty) {
      final reauthError = await _reauthenticateEmailPasswordUser(
        currentPassword,
      );
      if (reauthError != null) return 'Re-authentication failed: $reauthError';
    }

    try {
      await user.delete();
      try {
        if (await _googleSignIn.isSignedIn()) await _googleSignIn.signOut();
      } catch (_) {}
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'This operation requires you to have recently signed in. Please sign out and sign back in, then try again.';
      }
      return e.message ?? 'Failed to delete account.';
    } catch (e) {
      appLog('Auth', 'deleteAccount: $e');
      return 'An unexpected error occurred.';
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
