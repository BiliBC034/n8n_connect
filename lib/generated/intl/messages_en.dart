// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(number) => "Open the dialer with ${number}";

  static String m1(to) => "Write an email to ${to}";

  static String m2(app) => "Launch the app ${app}";

  static String m3(place) => "Open ${place} in Maps";

  static String m4(place) => "Navigate to ${place}";

  static String m5(panel) => "Open ${panel} settings";

  static String m6(key) => "Read the clipboard into ${key}";

  static String m7(text) => "Share text: ${text}";

  static String m8(number) => "Write a text message to ${number}";

  static String m9(time) => "Alarm set for ${time}";

  static String m10(time) => "Alarm scheduled for ${time}";

  static String m11(time, label) => "${time} · ${label} will not ring.";

  static String m12(app) => "App: ${app}";

  static String m13(email) => "Signed in as ${email}";

  static String m14(time) => "Set an alarm at ${time}";

  static String m15(title) => "Add calendar event: ${title}";

  static String m16(title) => "Show notification: ${title}";

  static String m17(app) => "Open the app ${app}";

  static String m18(url) => "Open ${url}";

  static String m19(permission) => "Ask for the ${permission} permission";

  static String m20(time) => "Schedule an alarm at ${time}";

  static String m21(duration) => "Start a ${duration} timer";

  static String m22(id) => "Device ${id}…";

  static String m23(type) => "The action \'${type}\' only works inside an app.";

  static String m24(message) => "Login failed: ${message}";

  static String m25(error) => "Page not found: ${error}";

  static String m26(message) => "Re-authentication failed: ${message}";

  static String m27(code) => "Server error (${code}).";

  static String m28(message) => "Sign up failed: ${message}";

  static String m29(field) => "Fill in \"${field}\".";

  static String m30(current, total) => "Page ${current} of ${total}";

  static String m31(time) => "Offline. Showing data saved at ${time}.";

  static String m32(time) => "Updated ${time}";

  static String m33(role) => "Role: ${role}";

  static String m34(type) => "Unsupported component: ${type}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "actDescribeDial": m0,
    "actDescribeEmail": m1,
    "actDescribeLaunchApp": m2,
    "actDescribeMap": m3,
    "actDescribeNavigate": m4,
    "actDescribeOpenSettings": m5,
    "actDescribeReadClipboard": m6,
    "actDescribeShare": m7,
    "actDescribeShowAlarms": MessageLookupByLibrary.simpleMessage(
      "Show alarms in the Clock app",
    ),
    "actDescribeSms": m8,
    "actDescribeVibrate": MessageLookupByLibrary.simpleMessage(
      "Vibrate the phone",
    ),
    "actShareChooser": MessageLookupByLibrary.simpleMessage("Share with"),
    "actionAlarmDone": m9,
    "actionCopied": MessageLookupByLibrary.simpleMessage("Copied to clipboard"),
    "actionScheduledAlarm": m10,
    "alarmsCancelConfirm": MessageLookupByLibrary.simpleMessage("Cancel alarm"),
    "alarmsCancelFailed": MessageLookupByLibrary.simpleMessage(
      "Could not cancel the alarm.",
    ),
    "alarmsCancelMessage": m11,
    "alarmsCancelTitle": MessageLookupByLibrary.simpleMessage(
      "Cancel this alarm?",
    ),
    "alarmsCancelTooltip": MessageLookupByLibrary.simpleMessage("Cancel alarm"),
    "alarmsCancelled": MessageLookupByLibrary.simpleMessage("Alarm cancelled"),
    "alarmsDefaultLabel": MessageLookupByLibrary.simpleMessage("Alarm"),
    "alarmsEmpty": MessageLookupByLibrary.simpleMessage(
      "No alarms yet. Apps with automatic actions can set alarms from n8n, and they will appear here.",
    ),
    "alarmsFromApp": m12,
    "alarmsLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Could not load the alarms.",
    ),
    "alarmsPassed": MessageLookupByLibrary.simpleMessage("Passed"),
    "alarmsRetry": MessageLookupByLibrary.simpleMessage("Retry"),
    "alarmsSnooze": MessageLookupByLibrary.simpleMessage("Snooze 5 min"),
    "alarmsStop": MessageLookupByLibrary.simpleMessage("Stop"),
    "alarmsTitle": MessageLookupByLibrary.simpleMessage("n8n alarms"),
    "alreadyHaveAccount": MessageLookupByLibrary.simpleMessage(
      "Already have an account?",
    ),
    "appTitle": MessageLookupByLibrary.simpleMessage("n8n Connect"),
    "appsEmpty": MessageLookupByLibrary.simpleMessage(
      "No apps yet. Add a row to the nc_apps data table of your n8n server.",
    ),
    "appsTitle": MessageLookupByLibrary.simpleMessage("My apps"),
    "automationDescription": MessageLookupByLibrary.simpleMessage(
      "Let this app set alarms and read your location without asking, even with the app closed.",
    ),
    "automationFailedTitle": MessageLookupByLibrary.simpleMessage(
      "An n8n automation failed",
    ),
    "automationRanTitle": MessageLookupByLibrary.simpleMessage(
      "n8n ran an automation",
    ),
    "automationTitle": MessageLookupByLibrary.simpleMessage(
      "Automatic actions",
    ),
    "backToHomeTooltip": MessageLookupByLibrary.simpleMessage("Back to Home"),
    "cancelButton": MessageLookupByLibrary.simpleMessage("Cancel"),
    "compDecrease": MessageLookupByLibrary.simpleMessage("Decrease"),
    "compIncrease": MessageLookupByLibrary.simpleMessage("Increase"),
    "confirmActionTitle": MessageLookupByLibrary.simpleMessage("Continue?"),
    "confirmPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "Confirm Password",
    ),
    "confirmReadClipboard": MessageLookupByLibrary.simpleMessage(
      "Let this app read your clipboard and use it in n8n?",
    ),
    "connectAllowListHint": MessageLookupByLibrary.simpleMessage(
      "This email must be enabled in the nc_users table of the server.",
    ),
    "connectButton": MessageLookupByLibrary.simpleMessage("Connect"),
    "connectSignedInAs": m13,
    "connectSubtitle": MessageLookupByLibrary.simpleMessage(
      "Enter the address of your n8n server. It must use HTTPS and have the \'n8n Connect · Core\' workflow published.",
    ),
    "connectTitle": MessageLookupByLibrary.simpleMessage("Connect your n8n"),
    "connectUrlLabel": MessageLookupByLibrary.simpleMessage("Server URL"),
    "darkTheme": MessageLookupByLibrary.simpleMessage("Dark"),
    "deleteAccountButton": MessageLookupByLibrary.simpleMessage(
      "Delete Account",
    ),
    "deleteButton": MessageLookupByLibrary.simpleMessage("Delete"),
    "describeAlarm": m14,
    "describeCalendarEvent": m15,
    "describeCancelAlarm": MessageLookupByLibrary.simpleMessage(
      "Cancel an alarm",
    ),
    "describeCopy": MessageLookupByLibrary.simpleMessage(
      "Copy text to the clipboard",
    ),
    "describeNotify": m16,
    "describeOpenApp": m17,
    "describeOpenUrl": m18,
    "describeReport": MessageLookupByLibrary.simpleMessage(
      "Send phone data (location) to n8n",
    ),
    "describeRequestPermission": m19,
    "describeScheduleAlarm": m20,
    "describeTimer": m21,
    "deviceIdLabel": m22,
    "dialogActionCancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "dialogActionConfirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "disconnectButton": MessageLookupByLibrary.simpleMessage(
      "Disconnect from server",
    ),
    "dontHaveAccount": MessageLookupByLibrary.simpleMessage(
      "Don\'t have an account?",
    ),
    "emailLabel": MessageLookupByLibrary.simpleMessage("Email"),
    "englishLanguage": MessageLookupByLibrary.simpleMessage("English"),
    "errorActionChainFailed": MessageLookupByLibrary.simpleMessage(
      "n8n answered with actions that could not run.",
    ),
    "errorActionNeedsScreen": m23,
    "errorAppNotFound": MessageLookupByLibrary.simpleMessage(
      "That app is no longer available on the server.",
    ),
    "errorBadResponse": MessageLookupByLibrary.simpleMessage(
      "Unexpected response from the server.",
    ),
    "errorBadSpec": MessageLookupByLibrary.simpleMessage(
      "The app sent by n8n has no screens or is malformed.",
    ),
    "errorDeleteAccount": MessageLookupByLibrary.simpleMessage(
      "Failed to delete account.",
    ),
    "errorDeviceAction": MessageLookupByLibrary.simpleMessage(
      "The phone could not run this action (is there an app for it?).",
    ),
    "errorEmailNotVerified": MessageLookupByLibrary.simpleMessage(
      "Verify your email before connecting.",
    ),
    "errorGeneric": MessageLookupByLibrary.simpleMessage(
      "An unexpected error occurred.",
    ),
    "errorInvalidAction": MessageLookupByLibrary.simpleMessage(
      "The action sent by n8n has invalid parameters.",
    ),
    "errorLoginFailed": m24,
    "errorNetwork": MessageLookupByLibrary.simpleMessage(
      "Could not reach the server. Check your connection.",
    ),
    "errorNotAllowed": MessageLookupByLibrary.simpleMessage(
      "Your account is not allowed on this server.",
    ),
    "errorNotConnected": MessageLookupByLibrary.simpleMessage(
      "Not connected to any server.",
    ),
    "errorNotN8nConnect": MessageLookupByLibrary.simpleMessage(
      "This URL is not an n8n Connect server (publish the \'n8n Connect · Core\' workflow).",
    ),
    "errorPageNotFound": m25,
    "errorPasswordTooShort": MessageLookupByLibrary.simpleMessage(
      "Password must be at least 6 characters.",
    ),
    "errorPasswordsDoNotMatch": MessageLookupByLibrary.simpleMessage(
      "Passwords do not match.",
    ),
    "errorReauthenticationFailed": m26,
    "errorRequiredField": MessageLookupByLibrary.simpleMessage(
      "Please fill in all required fields.",
    ),
    "errorRequiresRecentLogin": MessageLookupByLibrary.simpleMessage(
      "This operation requires you to have recently signed in. Please sign out and sign back in, then try again.",
    ),
    "errorServer": m27,
    "errorSessionInvalid": MessageLookupByLibrary.simpleMessage(
      "Your session with the server expired. Connect again.",
    ),
    "errorSignedOut": MessageLookupByLibrary.simpleMessage("Sign in first."),
    "errorSignupFailed": m28,
    "errorTimeout": MessageLookupByLibrary.simpleMessage(
      "The server took too long to respond.",
    ),
    "errorTitle": MessageLookupByLibrary.simpleMessage("Error"),
    "errorUnsupportedAction": MessageLookupByLibrary.simpleMessage(
      "This version of the app does not support that action.",
    ),
    "errorUnsupportedProtocol": MessageLookupByLibrary.simpleMessage(
      "The server uses a newer protocol version. Update the app.",
    ),
    "errorUnsupportedSpec": MessageLookupByLibrary.simpleMessage(
      "This app needs a newer version of n8n Connect.",
    ),
    "errorUpdateDisplayName": MessageLookupByLibrary.simpleMessage(
      "Failed to update display name.",
    ),
    "errorUpdatePassword": MessageLookupByLibrary.simpleMessage(
      "Failed to update password.",
    ),
    "errorUrlEmpty": MessageLookupByLibrary.simpleMessage(
      "Enter the URL of your n8n server.",
    ),
    "errorUrlForeignOrigin": MessageLookupByLibrary.simpleMessage(
      "Apps can only call your own n8n server.",
    ),
    "errorUrlInsecure": MessageLookupByLibrary.simpleMessage(
      "Only HTTPS servers are allowed: your login token would travel unencrypted.",
    ),
    "errorUrlInvalid": MessageLookupByLibrary.simpleMessage(
      "That URL is not valid.",
    ),
    "errorUserNotLoggedIn": MessageLookupByLibrary.simpleMessage(
      "Error: User not logged in.",
    ),
    "errorWebhookNotFound": MessageLookupByLibrary.simpleMessage(
      "That webhook does not exist. Is the workflow published in n8n?",
    ),
    "errorWrongFirebaseProject": MessageLookupByLibrary.simpleMessage(
      "This server is set up for a different app (Firebase project).",
    ),
    "fieldRequired": m29,
    "homePageTitle": MessageLookupByLibrary.simpleMessage("Home"),
    "inboxClearConfirm": MessageLookupByLibrary.simpleMessage("Clear"),
    "inboxClearMessage": MessageLookupByLibrary.simpleMessage(
      "All received pushes will be removed from this list.",
    ),
    "inboxClearTitle": MessageLookupByLibrary.simpleMessage("Clear inbox?"),
    "inboxClearTooltip": MessageLookupByLibrary.simpleMessage("Clear inbox"),
    "inboxEmpty": MessageLookupByLibrary.simpleMessage("No pushes yet"),
    "inboxEmptyHint": MessageLookupByLibrary.simpleMessage(
      "Messages sent from n8n will appear here.",
    ),
    "inboxRun": MessageLookupByLibrary.simpleMessage("Run"),
    "inboxStatusExecuted": MessageLookupByLibrary.simpleMessage("Executed"),
    "inboxStatusFailed": MessageLookupByLibrary.simpleMessage("Failed"),
    "inboxStatusIgnored": MessageLookupByLibrary.simpleMessage("Ignored"),
    "inboxStatusPending": MessageLookupByLibrary.simpleMessage("Pending"),
    "inboxTitle": MessageLookupByLibrary.simpleMessage("n8n inbox"),
    "inboxTooltip": MessageLookupByLibrary.simpleMessage("n8n inbox"),
    "inboxUntitled": MessageLookupByLibrary.simpleMessage("n8n message"),
    "languageName": MessageLookupByLibrary.simpleMessage("English"),
    "languageSettings": MessageLookupByLibrary.simpleMessage("Language"),
    "languageTitle": MessageLookupByLibrary.simpleMessage("Select Language"),
    "lightTheme": MessageLookupByLibrary.simpleMessage("Light"),
    "loginButton": MessageLookupByLibrary.simpleMessage("Login"),
    "loginFooter": MessageLookupByLibrary.simpleMessage(
      "Your n8n server decides which accounts can connect.",
    ),
    "loginPageTitle": MessageLookupByLibrary.simpleMessage("Login"),
    "loginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Sign in to connect your phone with your n8n workflows.",
    ),
    "logoutButton": MessageLookupByLibrary.simpleMessage("Sign Out"),
    "onboardingActionsBody": MessageLookupByLibrary.simpleMessage(
      "Workflows can set alarms, add calendar events, open maps, notify you or share content. They only run without asking if you allow it in Settings or in each app.",
    ),
    "onboardingActionsTitle": MessageLookupByLibrary.simpleMessage(
      "Actions on your phone",
    ),
    "onboardingAppsBody": MessageLookupByLibrary.simpleMessage(
      "Each app is a workflow that draws screens with forms, lists and live dashboards. When you tap a button, the workflow gets the data and replies.",
    ),
    "onboardingAppsTitle": MessageLookupByLibrary.simpleMessage(
      "Your apps, built in n8n",
    ),
    "onboardingDone": MessageLookupByLibrary.simpleMessage("Get started"),
    "onboardingNext": MessageLookupByLibrary.simpleMessage("Next"),
    "onboardingPageLabel": m30,
    "onboardingPermissionsBody": MessageLookupByLibrary.simpleMessage(
      "n8n can reach you even when the app is closed. Location is only requested when an app needs it, and you can change permissions in your phone\'s settings.",
    ),
    "onboardingPermissionsTitle": MessageLookupByLibrary.simpleMessage(
      "Notifications and permissions",
    ),
    "onboardingServerBody": MessageLookupByLibrary.simpleMessage(
      "Sign in with your account and enter the address of your n8n. Only accounts allowed on your server can get in, and every request carries a signed session.",
    ),
    "onboardingServerTitle": MessageLookupByLibrary.simpleMessage(
      "Connect your server",
    ),
    "onboardingSkip": MessageLookupByLibrary.simpleMessage("Skip"),
    "onboardingWelcomeBody": MessageLookupByLibrary.simpleMessage(
      "Use on your phone the apps you build with n8n workflows. Change a workflow and the app updates right away, with nothing new to install.",
    ),
    "onboardingWelcomeTitle": MessageLookupByLibrary.simpleMessage(
      "Welcome to n8n Connect",
    ),
    "orSignInWith": MessageLookupByLibrary.simpleMessage("Or sign in with"),
    "passwordLabel": MessageLookupByLibrary.simpleMessage("Password"),
    "permAlarmsTile": MessageLookupByLibrary.simpleMessage("n8n alarms"),
    "permAutomationsHint": MessageLookupByLibrary.simpleMessage(
      "Enable automatic actions from inside each app",
    ),
    "permAutomationsTitle": MessageLookupByLibrary.simpleMessage("Automations"),
    "permGrant": MessageLookupByLibrary.simpleMessage("Grant"),
    "permGranted": MessageLookupByLibrary.simpleMessage("Granted"),
    "permLocationAlwaysDescription": MessageLookupByLibrary.simpleMessage(
      "Needed so n8n can read where the phone is with the app closed, for example for the smart alarm.",
    ),
    "permLocationAlwaysTitle": MessageLookupByLibrary.simpleMessage(
      "Location all the time",
    ),
    "permLocationDescription": MessageLookupByLibrary.simpleMessage(
      "Lets n8n read where the phone is while the app is open.",
    ),
    "permLocationTitle": MessageLookupByLibrary.simpleMessage("Location"),
    "permNotificationsDescription": MessageLookupByLibrary.simpleMessage(
      "Lets n8n show alerts and notifications on this phone.",
    ),
    "permNotificationsTitle": MessageLookupByLibrary.simpleMessage(
      "Notifications",
    ),
    "permOpenSettings": MessageLookupByLibrary.simpleMessage("Open settings"),
    "permUnavailable": MessageLookupByLibrary.simpleMessage("Unavailable"),
    "pushAutoRunHint": MessageLookupByLibrary.simpleMessage(
      "When the app is open, run pushed actions without asking",
    ),
    "pushAutoRunTitle": MessageLookupByLibrary.simpleMessage(
      "Run n8n actions automatically",
    ),
    "pushDialogIgnore": MessageLookupByLibrary.simpleMessage("Ignore"),
    "pushDialogIntro": MessageLookupByLibrary.simpleMessage("Actions:"),
    "pushDialogRun": MessageLookupByLibrary.simpleMessage("Run"),
    "pushDialogTitle": MessageLookupByLibrary.simpleMessage(
      "n8n wants to run actions",
    ),
    "reloadTooltip": MessageLookupByLibrary.simpleMessage("Reload"),
    "retryButton": MessageLookupByLibrary.simpleMessage("Retry"),
    "runnerOfflineBanner": m31,
    "runnerUpdatedAt": m32,
    "saveButton": MessageLookupByLibrary.simpleMessage("Save"),
    "saveDetailsButton": MessageLookupByLibrary.simpleMessage("Save Details"),
    "selectedBingoCard": MessageLookupByLibrary.simpleMessage(
      "Selected Bingo Card",
    ),
    "serverChange": MessageLookupByLibrary.simpleMessage("Change server"),
    "serverNotConnected": MessageLookupByLibrary.simpleMessage("Not connected"),
    "serverResync": MessageLookupByLibrary.simpleMessage("Re-sync device"),
    "serverResyncDone": MessageLookupByLibrary.simpleMessage(
      "Device synced with the server",
    ),
    "serverResyncHint": MessageLookupByLibrary.simpleMessage(
      "Renews the session and the push token on the server",
    ),
    "serverRole": m33,
    "serverSectionTitle": MessageLookupByLibrary.simpleMessage("n8n server"),
    "settingsAboutTile": MessageLookupByLibrary.simpleMessage(
      "About n8n Connect",
    ),
    "settingsChangePasswordTile": MessageLookupByLibrary.simpleMessage(
      "Change Password",
    ),
    "settingsConfirmDeleteButton": MessageLookupByLibrary.simpleMessage(
      "Confirm Delete",
    ),
    "settingsConfirmDeleteNoPasswordPrompt": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to delete your account? This action cannot be undone.",
    ),
    "settingsConfirmDeletePasswordPrompt": MessageLookupByLibrary.simpleMessage(
      "For security, please enter your current password to delete your account. This action cannot be undone.",
    ),
    "settingsConfirmDeleteTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm Account Deletion",
    ),
    "settingsConfirmNewPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "Confirm New Password",
    ),
    "settingsCurrentPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "Current Password",
    ),
    "settingsDeleteAccountTile": MessageLookupByLibrary.simpleMessage(
      "Delete Account",
    ),
    "settingsDisplayNameHint": MessageLookupByLibrary.simpleMessage(
      "Enter your display name",
    ),
    "settingsDisplayNameLabel": MessageLookupByLibrary.simpleMessage(
      "Display Name",
    ),
    "settingsEmailLabel": MessageLookupByLibrary.simpleMessage("Email"),
    "settingsNewPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "New Password",
    ),
    "settingsSaveNameTooltip": MessageLookupByLibrary.simpleMessage(
      "Save Name",
    ),
    "settingsSignOutTile": MessageLookupByLibrary.simpleMessage("Sign Out"),
    "settingsTitle": MessageLookupByLibrary.simpleMessage("Settings"),
    "settingsTooltip": MessageLookupByLibrary.simpleMessage("Settings"),
    "settingsTutorialTile": MessageLookupByLibrary.simpleMessage(
      "View the tutorial",
    ),
    "settingsUpdatePasswordButton": MessageLookupByLibrary.simpleMessage(
      "Update Password",
    ),
    "shareNoteLabel": MessageLookupByLibrary.simpleMessage("Note (optional)"),
    "shareNothingToShare": MessageLookupByLibrary.simpleMessage(
      "Nothing to share yet.",
    ),
    "shareSendButton": MessageLookupByLibrary.simpleMessage("Send to n8n"),
    "shareSendHint": MessageLookupByLibrary.simpleMessage(
      "The text is sent to your n8n server.",
    ),
    "shareSent": MessageLookupByLibrary.simpleMessage("Sent to n8n."),
    "shareTitle": MessageLookupByLibrary.simpleMessage("Share to n8n"),
    "signupButton": MessageLookupByLibrary.simpleMessage("Sign Up"),
    "signupPageTitle": MessageLookupByLibrary.simpleMessage("Sign Up"),
    "spanishLanguage": MessageLookupByLibrary.simpleMessage("Spanish"),
    "successAccountDeleted": MessageLookupByLibrary.simpleMessage(
      "Account deleted successfully.",
    ),
    "successDisplayNameUpdated": MessageLookupByLibrary.simpleMessage(
      "Display name updated successfully!",
    ),
    "successPasswordUpdated": MessageLookupByLibrary.simpleMessage(
      "Password updated successfully!",
    ),
    "systemTheme": MessageLookupByLibrary.simpleMessage("System Default"),
    "themeSettings": MessageLookupByLibrary.simpleMessage("Theme"),
    "unsupportedComponent": m34,
    "useDeviceLanguage": MessageLookupByLibrary.simpleMessage(
      "Use Device Language",
    ),
    "userLabel": MessageLookupByLibrary.simpleMessage("User"),
    "userNotLoaded": MessageLookupByLibrary.simpleMessage("User not loaded."),
  };
}
