import 'package:flutter/services.dart';

import '../../generated/l10n.dart';
import '../actions/action_executor.dart';
import 'n8n_api.dart';
import 'server_url.dart';

/// Human readable, localized message for anything the app can throw while
/// talking to n8n or running actions.
String describeError(Object error) {
  final l10n = AppLocalizations.current;

  if (error is N8nApiException) {
    // Messages written by the n8n workflows are meant for the user.
    final serverMessage = error.message;
    final clientCode =
        error.isNetwork ||
        error.code == 'session_invalid' ||
        error.code == 'not_found' ||
        error.code.startsWith('http_');
    if (serverMessage != null && serverMessage.isNotEmpty && !clientCode) {
      return serverMessage;
    }
    switch (error.code) {
      case 'network':
        return l10n.errorNetwork;
      case 'timeout':
        return l10n.errorTimeout;
      case 'session_invalid':
        return l10n.errorSessionInvalid;
      case 'not_found':
        return l10n.errorWebhookNotFound;
      case 'bad_response':
        return l10n.errorBadResponse;
      case 'not_n8n_connect':
        return l10n.errorNotN8nConnect;
      case 'unsupported_protocol':
        return l10n.errorUnsupportedProtocol;
      case 'wrong_firebase_project':
        return l10n.errorWrongFirebaseProject;
      case 'not_connected':
        return l10n.errorNotConnected;
      case 'signed_out':
        return l10n.errorSignedOut;
      case 'not_allowed':
        return l10n.errorNotAllowed;
      case 'email_not_verified':
        return l10n.errorEmailNotVerified;
      case 'app_not_found':
        return l10n.errorAppNotFound;
      case 'unsupported_spec':
        return l10n.errorUnsupportedSpec;
      case 'bad_spec':
        return l10n.errorBadSpec;
      default:
        return l10n.errorServer(error.code);
    }
  }

  if (error is ServerUrlException) {
    switch (error.error) {
      case ServerUrlError.empty:
        return l10n.errorUrlEmpty;
      case ServerUrlError.invalid:
        return l10n.errorUrlInvalid;
      case ServerUrlError.insecure:
        return l10n.errorUrlInsecure;
      case ServerUrlError.foreignOrigin:
        return l10n.errorUrlForeignOrigin;
    }
  }

  if (error is ActionException) return error.message;
  if (error is PlatformException) return l10n.errorDeviceAction;
  if (error is ArgumentError) return l10n.errorInvalidAction;
  if (error is UnsupportedError) return l10n.errorUnsupportedAction;
  if (error is FormatException) return l10n.errorBadResponse;
  return l10n.errorGeneric;
}
