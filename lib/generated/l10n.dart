// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? _current;

  static AppLocalizations get current {
    assert(
      _current != null,
      'No instance of AppLocalizations was loaded. Try to initialize the AppLocalizations delegate before accessing AppLocalizations.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalizations();
      AppLocalizations._current = instance;

      return instance;
    });
  }

  static AppLocalizations of(BuildContext context) {
    final instance = AppLocalizations.maybeOf(context);
    assert(
      instance != null,
      'No instance of AppLocalizations present in the widget tree. Did you add AppLocalizations.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// `English`
  String get languageName {
    return Intl.message('English', name: 'languageName', desc: '', args: []);
  }

  /// `n8n Connect`
  String get appTitle {
    return Intl.message(
      'n8n Connect',
      name: 'appTitle',
      desc: 'The title of the application',
      args: [],
    );
  }

  /// `Settings`
  String get settingsTitle {
    return Intl.message('Settings', name: 'settingsTitle', desc: '', args: []);
  }

  /// `Settings`
  String get settingsTooltip {
    return Intl.message(
      'Settings',
      name: 'settingsTooltip',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get loginPageTitle {
    return Intl.message('Login', name: 'loginPageTitle', desc: '', args: []);
  }

  /// `Sign Up`
  String get signupPageTitle {
    return Intl.message('Sign Up', name: 'signupPageTitle', desc: '', args: []);
  }

  /// `Email`
  String get emailLabel {
    return Intl.message('Email', name: 'emailLabel', desc: '', args: []);
  }

  /// `Password`
  String get passwordLabel {
    return Intl.message('Password', name: 'passwordLabel', desc: '', args: []);
  }

  /// `Confirm Password`
  String get confirmPasswordLabel {
    return Intl.message(
      'Confirm Password',
      name: 'confirmPasswordLabel',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get loginButton {
    return Intl.message('Login', name: 'loginButton', desc: '', args: []);
  }

  /// `Sign Up`
  String get signupButton {
    return Intl.message('Sign Up', name: 'signupButton', desc: '', args: []);
  }

  /// `Or sign in with`
  String get orSignInWith {
    return Intl.message(
      'Or sign in with',
      name: 'orSignInWith',
      desc: '',
      args: [],
    );
  }

  /// `Don't have an account?`
  String get dontHaveAccount {
    return Intl.message(
      'Don\'t have an account?',
      name: 'dontHaveAccount',
      desc: '',
      args: [],
    );
  }

  /// `Already have an account?`
  String get alreadyHaveAccount {
    return Intl.message(
      'Already have an account?',
      name: 'alreadyHaveAccount',
      desc: '',
      args: [],
    );
  }

  /// `Sign Out`
  String get logoutButton {
    return Intl.message('Sign Out', name: 'logoutButton', desc: '', args: []);
  }

  /// `Delete Account`
  String get deleteAccountButton {
    return Intl.message(
      'Delete Account',
      name: 'deleteAccountButton',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get saveButton {
    return Intl.message('Save', name: 'saveButton', desc: '', args: []);
  }

  /// `Cancel`
  String get dialogActionCancel {
    return Intl.message(
      'Cancel',
      name: 'dialogActionCancel',
      desc: '',
      args: [],
    );
  }

  /// `Confirm`
  String get dialogActionConfirm {
    return Intl.message(
      'Confirm',
      name: 'dialogActionConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Login failed: {message}`
  String errorLoginFailed(Object message) {
    return Intl.message(
      'Login failed: $message',
      name: 'errorLoginFailed',
      desc: '',
      args: [message],
    );
  }

  /// `Sign up failed: {message}`
  String errorSignupFailed(Object message) {
    return Intl.message(
      'Sign up failed: $message',
      name: 'errorSignupFailed',
      desc: '',
      args: [message],
    );
  }

  /// `An unexpected error occurred.`
  String get errorGeneric {
    return Intl.message(
      'An unexpected error occurred.',
      name: 'errorGeneric',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get errorTitle {
    return Intl.message('Error', name: 'errorTitle', desc: '', args: []);
  }

  /// `Page not found: {error}`
  String errorPageNotFound(Object error) {
    return Intl.message(
      'Page not found: $error',
      name: 'errorPageNotFound',
      desc: '',
      args: [error],
    );
  }

  /// `Cancel`
  String get cancelButton {
    return Intl.message('Cancel', name: 'cancelButton', desc: '', args: []);
  }

  /// `Delete`
  String get deleteButton {
    return Intl.message('Delete', name: 'deleteButton', desc: '', args: []);
  }

  /// `Error: User not logged in.`
  String get errorUserNotLoggedIn {
    return Intl.message(
      'Error: User not logged in.',
      name: 'errorUserNotLoggedIn',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get settingsEmailLabel {
    return Intl.message(
      'Email',
      name: 'settingsEmailLabel',
      desc: '',
      args: [],
    );
  }

  /// `Display Name`
  String get settingsDisplayNameLabel {
    return Intl.message(
      'Display Name',
      name: 'settingsDisplayNameLabel',
      desc: '',
      args: [],
    );
  }

  /// `Enter your display name`
  String get settingsDisplayNameHint {
    return Intl.message(
      'Enter your display name',
      name: 'settingsDisplayNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Save Name`
  String get settingsSaveNameTooltip {
    return Intl.message(
      'Save Name',
      name: 'settingsSaveNameTooltip',
      desc: '',
      args: [],
    );
  }

  /// `Change Password`
  String get settingsChangePasswordTile {
    return Intl.message(
      'Change Password',
      name: 'settingsChangePasswordTile',
      desc: '',
      args: [],
    );
  }

  /// `Current Password`
  String get settingsCurrentPasswordLabel {
    return Intl.message(
      'Current Password',
      name: 'settingsCurrentPasswordLabel',
      desc: '',
      args: [],
    );
  }

  /// `New Password`
  String get settingsNewPasswordLabel {
    return Intl.message(
      'New Password',
      name: 'settingsNewPasswordLabel',
      desc: '',
      args: [],
    );
  }

  /// `Confirm New Password`
  String get settingsConfirmNewPasswordLabel {
    return Intl.message(
      'Confirm New Password',
      name: 'settingsConfirmNewPasswordLabel',
      desc: '',
      args: [],
    );
  }

  /// `Update Password`
  String get settingsUpdatePasswordButton {
    return Intl.message(
      'Update Password',
      name: 'settingsUpdatePasswordButton',
      desc: '',
      args: [],
    );
  }

  /// `Selected Bingo Card`
  String get selectedBingoCard {
    return Intl.message(
      'Selected Bingo Card',
      name: 'selectedBingoCard',
      desc: '',
      args: [],
    );
  }

  /// `Sign Out`
  String get settingsSignOutTile {
    return Intl.message(
      'Sign Out',
      name: 'settingsSignOutTile',
      desc: '',
      args: [],
    );
  }

  /// `Delete Account`
  String get settingsDeleteAccountTile {
    return Intl.message(
      'Delete Account',
      name: 'settingsDeleteAccountTile',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Account Deletion`
  String get settingsConfirmDeleteTitle {
    return Intl.message(
      'Confirm Account Deletion',
      name: 'settingsConfirmDeleteTitle',
      desc: '',
      args: [],
    );
  }

  /// `For security, please enter your current password to delete your account. This action cannot be undone.`
  String get settingsConfirmDeletePasswordPrompt {
    return Intl.message(
      'For security, please enter your current password to delete your account. This action cannot be undone.',
      name: 'settingsConfirmDeletePasswordPrompt',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete your account? This action cannot be undone.`
  String get settingsConfirmDeleteNoPasswordPrompt {
    return Intl.message(
      'Are you sure you want to delete your account? This action cannot be undone.',
      name: 'settingsConfirmDeleteNoPasswordPrompt',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Delete`
  String get settingsConfirmDeleteButton {
    return Intl.message(
      'Confirm Delete',
      name: 'settingsConfirmDeleteButton',
      desc: '',
      args: [],
    );
  }

  /// `Display name updated successfully!`
  String get successDisplayNameUpdated {
    return Intl.message(
      'Display name updated successfully!',
      name: 'successDisplayNameUpdated',
      desc: '',
      args: [],
    );
  }

  /// `Password updated successfully!`
  String get successPasswordUpdated {
    return Intl.message(
      'Password updated successfully!',
      name: 'successPasswordUpdated',
      desc: '',
      args: [],
    );
  }

  /// `Account deleted successfully.`
  String get successAccountDeleted {
    return Intl.message(
      'Account deleted successfully.',
      name: 'successAccountDeleted',
      desc: '',
      args: [],
    );
  }

  /// `Failed to update display name.`
  String get errorUpdateDisplayName {
    return Intl.message(
      'Failed to update display name.',
      name: 'errorUpdateDisplayName',
      desc: '',
      args: [],
    );
  }

  /// `Failed to update password.`
  String get errorUpdatePassword {
    return Intl.message(
      'Failed to update password.',
      name: 'errorUpdatePassword',
      desc: '',
      args: [],
    );
  }

  /// `Failed to delete account.`
  String get errorDeleteAccount {
    return Intl.message(
      'Failed to delete account.',
      name: 'errorDeleteAccount',
      desc: '',
      args: [],
    );
  }

  /// `Re-authentication failed: {message}`
  String errorReauthenticationFailed(Object message) {
    return Intl.message(
      'Re-authentication failed: $message',
      name: 'errorReauthenticationFailed',
      desc: '',
      args: [message],
    );
  }

  /// `This operation requires you to have recently signed in. Please sign out and sign back in, then try again.`
  String get errorRequiresRecentLogin {
    return Intl.message(
      'This operation requires you to have recently signed in. Please sign out and sign back in, then try again.',
      name: 'errorRequiresRecentLogin',
      desc: '',
      args: [],
    );
  }

  /// `User not loaded.`
  String get userNotLoaded {
    return Intl.message(
      'User not loaded.',
      name: 'userNotLoaded',
      desc: '',
      args: [],
    );
  }

  /// `Back to Home`
  String get backToHomeTooltip {
    return Intl.message(
      'Back to Home',
      name: 'backToHomeTooltip',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get languageSettings {
    return Intl.message(
      'Language',
      name: 'languageSettings',
      desc: '',
      args: [],
    );
  }

  /// `Select Language`
  String get languageTitle {
    return Intl.message(
      'Select Language',
      name: 'languageTitle',
      desc: '',
      args: [],
    );
  }

  /// `Use Device Language`
  String get useDeviceLanguage {
    return Intl.message(
      'Use Device Language',
      name: 'useDeviceLanguage',
      desc: '',
      args: [],
    );
  }

  /// `English`
  String get englishLanguage {
    return Intl.message('English', name: 'englishLanguage', desc: '', args: []);
  }

  /// `Spanish`
  String get spanishLanguage {
    return Intl.message('Spanish', name: 'spanishLanguage', desc: '', args: []);
  }

  /// `Theme`
  String get themeSettings {
    return Intl.message('Theme', name: 'themeSettings', desc: '', args: []);
  }

  /// `Light`
  String get lightTheme {
    return Intl.message('Light', name: 'lightTheme', desc: '', args: []);
  }

  /// `Dark`
  String get darkTheme {
    return Intl.message('Dark', name: 'darkTheme', desc: '', args: []);
  }

  /// `System Default`
  String get systemTheme {
    return Intl.message(
      'System Default',
      name: 'systemTheme',
      desc: '',
      args: [],
    );
  }

  /// `Save Details`
  String get saveDetailsButton {
    return Intl.message(
      'Save Details',
      name: 'saveDetailsButton',
      desc: '',
      args: [],
    );
  }

  /// `Please fill in all required fields.`
  String get errorRequiredField {
    return Intl.message(
      'Please fill in all required fields.',
      name: 'errorRequiredField',
      desc: '',
      args: [],
    );
  }

  /// `Passwords do not match.`
  String get errorPasswordsDoNotMatch {
    return Intl.message(
      'Passwords do not match.',
      name: 'errorPasswordsDoNotMatch',
      desc: '',
      args: [],
    );
  }

  /// `Password must be at least 6 characters.`
  String get errorPasswordTooShort {
    return Intl.message(
      'Password must be at least 6 characters.',
      name: 'errorPasswordTooShort',
      desc: '',
      args: [],
    );
  }

  /// `Home`
  String get homePageTitle {
    return Intl.message('Home', name: 'homePageTitle', desc: '', args: []);
  }

  /// `User`
  String get userLabel {
    return Intl.message('User', name: 'userLabel', desc: '', args: []);
  }

  /// `Could not reach the server. Check your connection.`
  String get errorNetwork {
    return Intl.message(
      'Could not reach the server. Check your connection.',
      name: 'errorNetwork',
      desc: '',
      args: [],
    );
  }

  /// `The server took too long to respond.`
  String get errorTimeout {
    return Intl.message(
      'The server took too long to respond.',
      name: 'errorTimeout',
      desc: '',
      args: [],
    );
  }

  /// `Your session with the server expired. Connect again.`
  String get errorSessionInvalid {
    return Intl.message(
      'Your session with the server expired. Connect again.',
      name: 'errorSessionInvalid',
      desc: '',
      args: [],
    );
  }

  /// `That webhook does not exist. Is the workflow published in n8n?`
  String get errorWebhookNotFound {
    return Intl.message(
      'That webhook does not exist. Is the workflow published in n8n?',
      name: 'errorWebhookNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Unexpected response from the server.`
  String get errorBadResponse {
    return Intl.message(
      'Unexpected response from the server.',
      name: 'errorBadResponse',
      desc: '',
      args: [],
    );
  }

  /// `This URL is not an n8n Connect server (publish the 'n8n Connect · Core' workflow).`
  String get errorNotN8nConnect {
    return Intl.message(
      'This URL is not an n8n Connect server (publish the \'n8n Connect · Core\' workflow).',
      name: 'errorNotN8nConnect',
      desc: '',
      args: [],
    );
  }

  /// `The server uses a newer protocol version. Update the app.`
  String get errorUnsupportedProtocol {
    return Intl.message(
      'The server uses a newer protocol version. Update the app.',
      name: 'errorUnsupportedProtocol',
      desc: '',
      args: [],
    );
  }

  /// `This server is set up for a different app (Firebase project).`
  String get errorWrongFirebaseProject {
    return Intl.message(
      'This server is set up for a different app (Firebase project).',
      name: 'errorWrongFirebaseProject',
      desc: '',
      args: [],
    );
  }

  /// `Not connected to any server.`
  String get errorNotConnected {
    return Intl.message(
      'Not connected to any server.',
      name: 'errorNotConnected',
      desc: '',
      args: [],
    );
  }

  /// `Sign in first.`
  String get errorSignedOut {
    return Intl.message(
      'Sign in first.',
      name: 'errorSignedOut',
      desc: '',
      args: [],
    );
  }

  /// `Your account is not allowed on this server.`
  String get errorNotAllowed {
    return Intl.message(
      'Your account is not allowed on this server.',
      name: 'errorNotAllowed',
      desc: '',
      args: [],
    );
  }

  /// `Verify your email before connecting.`
  String get errorEmailNotVerified {
    return Intl.message(
      'Verify your email before connecting.',
      name: 'errorEmailNotVerified',
      desc: '',
      args: [],
    );
  }

  /// `Server error ({code}).`
  String errorServer(String code) {
    return Intl.message(
      'Server error ($code).',
      name: 'errorServer',
      desc: '',
      args: [code],
    );
  }

  /// `Enter the URL of your n8n server.`
  String get errorUrlEmpty {
    return Intl.message(
      'Enter the URL of your n8n server.',
      name: 'errorUrlEmpty',
      desc: '',
      args: [],
    );
  }

  /// `That URL is not valid.`
  String get errorUrlInvalid {
    return Intl.message(
      'That URL is not valid.',
      name: 'errorUrlInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Only HTTPS servers are allowed: your login token would travel unencrypted.`
  String get errorUrlInsecure {
    return Intl.message(
      'Only HTTPS servers are allowed: your login token would travel unencrypted.',
      name: 'errorUrlInsecure',
      desc: '',
      args: [],
    );
  }

  /// `Apps can only call your own n8n server.`
  String get errorUrlForeignOrigin {
    return Intl.message(
      'Apps can only call your own n8n server.',
      name: 'errorUrlForeignOrigin',
      desc: '',
      args: [],
    );
  }

  /// `The phone could not run this action (is there an app for it?).`
  String get errorDeviceAction {
    return Intl.message(
      'The phone could not run this action (is there an app for it?).',
      name: 'errorDeviceAction',
      desc: '',
      args: [],
    );
  }

  /// `The action sent by n8n has invalid parameters.`
  String get errorInvalidAction {
    return Intl.message(
      'The action sent by n8n has invalid parameters.',
      name: 'errorInvalidAction',
      desc: '',
      args: [],
    );
  }

  /// `This version of the app does not support that action.`
  String get errorUnsupportedAction {
    return Intl.message(
      'This version of the app does not support that action.',
      name: 'errorUnsupportedAction',
      desc: '',
      args: [],
    );
  }

  /// `The action '{type}' only works inside an app.`
  String errorActionNeedsScreen(String type) {
    return Intl.message(
      'The action \'$type\' only works inside an app.',
      name: 'errorActionNeedsScreen',
      desc: '',
      args: [type],
    );
  }

  /// `Continue?`
  String get confirmActionTitle {
    return Intl.message(
      'Continue?',
      name: 'confirmActionTitle',
      desc: '',
      args: [],
    );
  }

  /// `Alarm set for {time}`
  String actionAlarmDone(String time) {
    return Intl.message(
      'Alarm set for $time',
      name: 'actionAlarmDone',
      desc: '',
      args: [time],
    );
  }

  /// `Copied to clipboard`
  String get actionCopied {
    return Intl.message(
      'Copied to clipboard',
      name: 'actionCopied',
      desc: '',
      args: [],
    );
  }

  /// `Set an alarm at {time}`
  String describeAlarm(String time) {
    return Intl.message(
      'Set an alarm at $time',
      name: 'describeAlarm',
      desc: '',
      args: [time],
    );
  }

  /// `Start a {duration} timer`
  String describeTimer(String duration) {
    return Intl.message(
      'Start a $duration timer',
      name: 'describeTimer',
      desc: '',
      args: [duration],
    );
  }

  /// `Add calendar event: {title}`
  String describeCalendarEvent(String title) {
    return Intl.message(
      'Add calendar event: $title',
      name: 'describeCalendarEvent',
      desc: '',
      args: [title],
    );
  }

  /// `Open {url}`
  String describeOpenUrl(String url) {
    return Intl.message(
      'Open $url',
      name: 'describeOpenUrl',
      desc: '',
      args: [url],
    );
  }

  /// `Show notification: {title}`
  String describeNotify(String title) {
    return Intl.message(
      'Show notification: $title',
      name: 'describeNotify',
      desc: '',
      args: [title],
    );
  }

  /// `Copy text to the clipboard`
  String get describeCopy {
    return Intl.message(
      'Copy text to the clipboard',
      name: 'describeCopy',
      desc: '',
      args: [],
    );
  }

  /// `Open the app {app}`
  String describeOpenApp(String app) {
    return Intl.message(
      'Open the app $app',
      name: 'describeOpenApp',
      desc: '',
      args: [app],
    );
  }

  /// `That app is no longer available on the server.`
  String get errorAppNotFound {
    return Intl.message(
      'That app is no longer available on the server.',
      name: 'errorAppNotFound',
      desc: '',
      args: [],
    );
  }

  /// `This app needs a newer version of n8n Connect.`
  String get errorUnsupportedSpec {
    return Intl.message(
      'This app needs a newer version of n8n Connect.',
      name: 'errorUnsupportedSpec',
      desc: '',
      args: [],
    );
  }

  /// `The app sent by n8n has no screens or is malformed.`
  String get errorBadSpec {
    return Intl.message(
      'The app sent by n8n has no screens or is malformed.',
      name: 'errorBadSpec',
      desc: '',
      args: [],
    );
  }

  /// `Unsupported component: {type}`
  String unsupportedComponent(String type) {
    return Intl.message(
      'Unsupported component: $type',
      name: 'unsupportedComponent',
      desc: '',
      args: [type],
    );
  }

  /// `Fill in "{field}".`
  String fieldRequired(String field) {
    return Intl.message(
      'Fill in "$field".',
      name: 'fieldRequired',
      desc: '',
      args: [field],
    );
  }

  /// `Reload`
  String get reloadTooltip {
    return Intl.message('Reload', name: 'reloadTooltip', desc: '', args: []);
  }

  /// `Retry`
  String get retryButton {
    return Intl.message('Retry', name: 'retryButton', desc: '', args: []);
  }

  /// `My apps`
  String get appsTitle {
    return Intl.message('My apps', name: 'appsTitle', desc: '', args: []);
  }

  /// `No apps yet. Add a row to the nc_apps data table of your n8n server.`
  String get appsEmpty {
    return Intl.message(
      'No apps yet. Add a row to the nc_apps data table of your n8n server.',
      name: 'appsEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Sign in to connect your phone with your n8n workflows.`
  String get loginSubtitle {
    return Intl.message(
      'Sign in to connect your phone with your n8n workflows.',
      name: 'loginSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Your n8n server decides which accounts can connect.`
  String get loginFooter {
    return Intl.message(
      'Your n8n server decides which accounts can connect.',
      name: 'loginFooter',
      desc: '',
      args: [],
    );
  }

  /// `Connect your n8n`
  String get connectTitle {
    return Intl.message(
      'Connect your n8n',
      name: 'connectTitle',
      desc: '',
      args: [],
    );
  }

  /// `Enter the address of your n8n server. It must use HTTPS and have the 'n8n Connect · Core' workflow published.`
  String get connectSubtitle {
    return Intl.message(
      'Enter the address of your n8n server. It must use HTTPS and have the \'n8n Connect · Core\' workflow published.',
      name: 'connectSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Server URL`
  String get connectUrlLabel {
    return Intl.message(
      'Server URL',
      name: 'connectUrlLabel',
      desc: '',
      args: [],
    );
  }

  /// `Connect`
  String get connectButton {
    return Intl.message('Connect', name: 'connectButton', desc: '', args: []);
  }

  /// `Disconnect from server`
  String get disconnectButton {
    return Intl.message(
      'Disconnect from server',
      name: 'disconnectButton',
      desc: '',
      args: [],
    );
  }

  /// `Signed in as {email}`
  String connectSignedInAs(String email) {
    return Intl.message(
      'Signed in as $email',
      name: 'connectSignedInAs',
      desc: '',
      args: [email],
    );
  }

  /// `This email must be enabled in the nc_users table of the server.`
  String get connectAllowListHint {
    return Intl.message(
      'This email must be enabled in the nc_users table of the server.',
      name: 'connectAllowListHint',
      desc: '',
      args: [],
    );
  }

  /// `n8n wants to run actions`
  String get pushDialogTitle {
    return Intl.message(
      'n8n wants to run actions',
      name: 'pushDialogTitle',
      desc: '',
      args: [],
    );
  }

  /// `Actions:`
  String get pushDialogIntro {
    return Intl.message(
      'Actions:',
      name: 'pushDialogIntro',
      desc: '',
      args: [],
    );
  }

  /// `Ignore`
  String get pushDialogIgnore {
    return Intl.message('Ignore', name: 'pushDialogIgnore', desc: '', args: []);
  }

  /// `Run`
  String get pushDialogRun {
    return Intl.message('Run', name: 'pushDialogRun', desc: '', args: []);
  }

  /// `n8n server`
  String get serverSectionTitle {
    return Intl.message(
      'n8n server',
      name: 'serverSectionTitle',
      desc: '',
      args: [],
    );
  }

  /// `Not connected`
  String get serverNotConnected {
    return Intl.message(
      'Not connected',
      name: 'serverNotConnected',
      desc: '',
      args: [],
    );
  }

  /// `Role: {role}`
  String serverRole(String role) {
    return Intl.message(
      'Role: $role',
      name: 'serverRole',
      desc: '',
      args: [role],
    );
  }

  /// `Re-sync device`
  String get serverResync {
    return Intl.message(
      'Re-sync device',
      name: 'serverResync',
      desc: '',
      args: [],
    );
  }

  /// `Renews the session and the push token on the server`
  String get serverResyncHint {
    return Intl.message(
      'Renews the session and the push token on the server',
      name: 'serverResyncHint',
      desc: '',
      args: [],
    );
  }

  /// `Device synced with the server`
  String get serverResyncDone {
    return Intl.message(
      'Device synced with the server',
      name: 'serverResyncDone',
      desc: '',
      args: [],
    );
  }

  /// `Change server`
  String get serverChange {
    return Intl.message(
      'Change server',
      name: 'serverChange',
      desc: '',
      args: [],
    );
  }

  /// `Run n8n actions automatically`
  String get pushAutoRunTitle {
    return Intl.message(
      'Run n8n actions automatically',
      name: 'pushAutoRunTitle',
      desc: '',
      args: [],
    );
  }

  /// `When the app is open, run pushed actions without asking`
  String get pushAutoRunHint {
    return Intl.message(
      'When the app is open, run pushed actions without asking',
      name: 'pushAutoRunHint',
      desc: '',
      args: [],
    );
  }

  /// `Device {id}…`
  String deviceIdLabel(String id) {
    return Intl.message(
      'Device $id…',
      name: 'deviceIdLabel',
      desc: '',
      args: [id],
    );
  }

  /// `n8n inbox`
  String get inboxTooltip {
    return Intl.message('n8n inbox', name: 'inboxTooltip', desc: '', args: []);
  }

  /// `n8n inbox`
  String get inboxTitle {
    return Intl.message('n8n inbox', name: 'inboxTitle', desc: '', args: []);
  }

  /// `Clear inbox`
  String get inboxClearTooltip {
    return Intl.message(
      'Clear inbox',
      name: 'inboxClearTooltip',
      desc: '',
      args: [],
    );
  }

  /// `Clear inbox?`
  String get inboxClearTitle {
    return Intl.message(
      'Clear inbox?',
      name: 'inboxClearTitle',
      desc: '',
      args: [],
    );
  }

  /// `All received pushes will be removed from this list.`
  String get inboxClearMessage {
    return Intl.message(
      'All received pushes will be removed from this list.',
      name: 'inboxClearMessage',
      desc: '',
      args: [],
    );
  }

  /// `Clear`
  String get inboxClearConfirm {
    return Intl.message('Clear', name: 'inboxClearConfirm', desc: '', args: []);
  }

  /// `No pushes yet`
  String get inboxEmpty {
    return Intl.message(
      'No pushes yet',
      name: 'inboxEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Messages sent from n8n will appear here.`
  String get inboxEmptyHint {
    return Intl.message(
      'Messages sent from n8n will appear here.',
      name: 'inboxEmptyHint',
      desc: '',
      args: [],
    );
  }

  /// `n8n message`
  String get inboxUntitled {
    return Intl.message(
      'n8n message',
      name: 'inboxUntitled',
      desc: '',
      args: [],
    );
  }

  /// `Run`
  String get inboxRun {
    return Intl.message('Run', name: 'inboxRun', desc: '', args: []);
  }

  /// `Pending`
  String get inboxStatusPending {
    return Intl.message(
      'Pending',
      name: 'inboxStatusPending',
      desc: '',
      args: [],
    );
  }

  /// `Executed`
  String get inboxStatusExecuted {
    return Intl.message(
      'Executed',
      name: 'inboxStatusExecuted',
      desc: '',
      args: [],
    );
  }

  /// `Ignored`
  String get inboxStatusIgnored {
    return Intl.message(
      'Ignored',
      name: 'inboxStatusIgnored',
      desc: '',
      args: [],
    );
  }

  /// `Failed`
  String get inboxStatusFailed {
    return Intl.message(
      'Failed',
      name: 'inboxStatusFailed',
      desc: '',
      args: [],
    );
  }

  /// `Share to n8n`
  String get shareTitle {
    return Intl.message('Share to n8n', name: 'shareTitle', desc: '', args: []);
  }

  /// `The text is sent to your n8n server.`
  String get shareSendHint {
    return Intl.message(
      'The text is sent to your n8n server.',
      name: 'shareSendHint',
      desc: '',
      args: [],
    );
  }

  /// `Nothing to share yet.`
  String get shareNothingToShare {
    return Intl.message(
      'Nothing to share yet.',
      name: 'shareNothingToShare',
      desc: '',
      args: [],
    );
  }

  /// `Note (optional)`
  String get shareNoteLabel {
    return Intl.message(
      'Note (optional)',
      name: 'shareNoteLabel',
      desc: '',
      args: [],
    );
  }

  /// `Send to n8n`
  String get shareSendButton {
    return Intl.message(
      'Send to n8n',
      name: 'shareSendButton',
      desc: '',
      args: [],
    );
  }

  /// `Sent to n8n.`
  String get shareSent {
    return Intl.message('Sent to n8n.', name: 'shareSent', desc: '', args: []);
  }

  /// `Decrease`
  String get compDecrease {
    return Intl.message('Decrease', name: 'compDecrease', desc: '', args: []);
  }

  /// `Increase`
  String get compIncrease {
    return Intl.message('Increase', name: 'compIncrease', desc: '', args: []);
  }

  /// `Offline. Showing data saved at {time}.`
  String runnerOfflineBanner(String time) {
    return Intl.message(
      'Offline. Showing data saved at $time.',
      name: 'runnerOfflineBanner',
      desc: '',
      args: [time],
    );
  }

  /// `Updated {time}`
  String runnerUpdatedAt(String time) {
    return Intl.message(
      'Updated $time',
      name: 'runnerUpdatedAt',
      desc: '',
      args: [time],
    );
  }

  /// `Share with`
  String get actShareChooser {
    return Intl.message(
      'Share with',
      name: 'actShareChooser',
      desc: '',
      args: [],
    );
  }

  /// `Share text: {text}`
  String actDescribeShare(String text) {
    return Intl.message(
      'Share text: $text',
      name: 'actDescribeShare',
      desc: '',
      args: [text],
    );
  }

  /// `Open the dialer with {number}`
  String actDescribeDial(String number) {
    return Intl.message(
      'Open the dialer with $number',
      name: 'actDescribeDial',
      desc: '',
      args: [number],
    );
  }

  /// `Write a text message to {number}`
  String actDescribeSms(String number) {
    return Intl.message(
      'Write a text message to $number',
      name: 'actDescribeSms',
      desc: '',
      args: [number],
    );
  }

  /// `Write an email to {to}`
  String actDescribeEmail(String to) {
    return Intl.message(
      'Write an email to $to',
      name: 'actDescribeEmail',
      desc: '',
      args: [to],
    );
  }

  /// `Open {place} in Maps`
  String actDescribeMap(String place) {
    return Intl.message(
      'Open $place in Maps',
      name: 'actDescribeMap',
      desc: '',
      args: [place],
    );
  }

  /// `Navigate to {place}`
  String actDescribeNavigate(String place) {
    return Intl.message(
      'Navigate to $place',
      name: 'actDescribeNavigate',
      desc: '',
      args: [place],
    );
  }

  /// `Vibrate the phone`
  String get actDescribeVibrate {
    return Intl.message(
      'Vibrate the phone',
      name: 'actDescribeVibrate',
      desc: '',
      args: [],
    );
  }

  /// `Show alarms in the Clock app`
  String get actDescribeShowAlarms {
    return Intl.message(
      'Show alarms in the Clock app',
      name: 'actDescribeShowAlarms',
      desc: '',
      args: [],
    );
  }

  /// `Open {panel} settings`
  String actDescribeOpenSettings(String panel) {
    return Intl.message(
      'Open $panel settings',
      name: 'actDescribeOpenSettings',
      desc: '',
      args: [panel],
    );
  }

  /// `Launch the app {app}`
  String actDescribeLaunchApp(String app) {
    return Intl.message(
      'Launch the app $app',
      name: 'actDescribeLaunchApp',
      desc: '',
      args: [app],
    );
  }

  /// `Read the clipboard into {key}`
  String actDescribeReadClipboard(String key) {
    return Intl.message(
      'Read the clipboard into $key',
      name: 'actDescribeReadClipboard',
      desc: '',
      args: [key],
    );
  }

  /// `Let this app read your clipboard and use it in n8n?`
  String get confirmReadClipboard {
    return Intl.message(
      'Let this app read your clipboard and use it in n8n?',
      name: 'confirmReadClipboard',
      desc: '',
      args: [],
    );
  }

  /// `Alarm scheduled for {time}`
  String actionScheduledAlarm(String time) {
    return Intl.message(
      'Alarm scheduled for $time',
      name: 'actionScheduledAlarm',
      desc: '',
      args: [time],
    );
  }

  /// `n8n answered with actions that could not run.`
  String get errorActionChainFailed {
    return Intl.message(
      'n8n answered with actions that could not run.',
      name: 'errorActionChainFailed',
      desc: '',
      args: [],
    );
  }

  /// `Schedule an alarm at {time}`
  String describeScheduleAlarm(String time) {
    return Intl.message(
      'Schedule an alarm at $time',
      name: 'describeScheduleAlarm',
      desc: '',
      args: [time],
    );
  }

  /// `Cancel an alarm`
  String get describeCancelAlarm {
    return Intl.message(
      'Cancel an alarm',
      name: 'describeCancelAlarm',
      desc: '',
      args: [],
    );
  }

  /// `Send phone data (location) to n8n`
  String get describeReport {
    return Intl.message(
      'Send phone data (location) to n8n',
      name: 'describeReport',
      desc: '',
      args: [],
    );
  }

  /// `Ask for the {permission} permission`
  String describeRequestPermission(String permission) {
    return Intl.message(
      'Ask for the $permission permission',
      name: 'describeRequestPermission',
      desc: '',
      args: [permission],
    );
  }

  /// `Automatic actions`
  String get automationTitle {
    return Intl.message(
      'Automatic actions',
      name: 'automationTitle',
      desc: '',
      args: [],
    );
  }

  /// `Let this app set alarms and read your location without asking, even with the app closed.`
  String get automationDescription {
    return Intl.message(
      'Let this app set alarms and read your location without asking, even with the app closed.',
      name: 'automationDescription',
      desc: '',
      args: [],
    );
  }

  /// `n8n ran an automation`
  String get automationRanTitle {
    return Intl.message(
      'n8n ran an automation',
      name: 'automationRanTitle',
      desc: '',
      args: [],
    );
  }

  /// `An n8n automation failed`
  String get automationFailedTitle {
    return Intl.message(
      'An n8n automation failed',
      name: 'automationFailedTitle',
      desc: '',
      args: [],
    );
  }

  /// `Location`
  String get permLocationTitle {
    return Intl.message(
      'Location',
      name: 'permLocationTitle',
      desc: '',
      args: [],
    );
  }

  /// `Location all the time`
  String get permLocationAlwaysTitle {
    return Intl.message(
      'Location all the time',
      name: 'permLocationAlwaysTitle',
      desc: '',
      args: [],
    );
  }

  /// `Notifications`
  String get permNotificationsTitle {
    return Intl.message(
      'Notifications',
      name: 'permNotificationsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Lets n8n read where the phone is while the app is open.`
  String get permLocationDescription {
    return Intl.message(
      'Lets n8n read where the phone is while the app is open.',
      name: 'permLocationDescription',
      desc: '',
      args: [],
    );
  }

  /// `Needed so n8n can read where the phone is with the app closed, for example for the smart alarm.`
  String get permLocationAlwaysDescription {
    return Intl.message(
      'Needed so n8n can read where the phone is with the app closed, for example for the smart alarm.',
      name: 'permLocationAlwaysDescription',
      desc: '',
      args: [],
    );
  }

  /// `Lets n8n show alerts and notifications on this phone.`
  String get permNotificationsDescription {
    return Intl.message(
      'Lets n8n show alerts and notifications on this phone.',
      name: 'permNotificationsDescription',
      desc: '',
      args: [],
    );
  }

  /// `Granted`
  String get permGranted {
    return Intl.message('Granted', name: 'permGranted', desc: '', args: []);
  }

  /// `Grant`
  String get permGrant {
    return Intl.message('Grant', name: 'permGrant', desc: '', args: []);
  }

  /// `Open settings`
  String get permOpenSettings {
    return Intl.message(
      'Open settings',
      name: 'permOpenSettings',
      desc: '',
      args: [],
    );
  }

  /// `Unavailable`
  String get permUnavailable {
    return Intl.message(
      'Unavailable',
      name: 'permUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Automations`
  String get permAutomationsTitle {
    return Intl.message(
      'Automations',
      name: 'permAutomationsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Enable automatic actions from inside each app`
  String get permAutomationsHint {
    return Intl.message(
      'Enable automatic actions from inside each app',
      name: 'permAutomationsHint',
      desc: '',
      args: [],
    );
  }

  /// `n8n alarms`
  String get permAlarmsTile {
    return Intl.message(
      'n8n alarms',
      name: 'permAlarmsTile',
      desc: '',
      args: [],
    );
  }

  /// `n8n alarms`
  String get alarmsTitle {
    return Intl.message('n8n alarms', name: 'alarmsTitle', desc: '', args: []);
  }

  /// `No alarms yet. Apps with automatic actions can set alarms from n8n, and they will appear here.`
  String get alarmsEmpty {
    return Intl.message(
      'No alarms yet. Apps with automatic actions can set alarms from n8n, and they will appear here.',
      name: 'alarmsEmpty',
      desc: '',
      args: [],
    );
  }

  /// `App: {app}`
  String alarmsFromApp(String app) {
    return Intl.message(
      'App: $app',
      name: 'alarmsFromApp',
      desc: '',
      args: [app],
    );
  }

  /// `Passed`
  String get alarmsPassed {
    return Intl.message('Passed', name: 'alarmsPassed', desc: '', args: []);
  }

  /// `Alarm`
  String get alarmsDefaultLabel {
    return Intl.message(
      'Alarm',
      name: 'alarmsDefaultLabel',
      desc: '',
      args: [],
    );
  }

  /// `Cancel alarm`
  String get alarmsCancelTooltip {
    return Intl.message(
      'Cancel alarm',
      name: 'alarmsCancelTooltip',
      desc: '',
      args: [],
    );
  }

  /// `Cancel this alarm?`
  String get alarmsCancelTitle {
    return Intl.message(
      'Cancel this alarm?',
      name: 'alarmsCancelTitle',
      desc: '',
      args: [],
    );
  }

  /// `{time} · {label} will not ring.`
  String alarmsCancelMessage(String time, String label) {
    return Intl.message(
      '$time · $label will not ring.',
      name: 'alarmsCancelMessage',
      desc: '',
      args: [time, label],
    );
  }

  /// `Cancel alarm`
  String get alarmsCancelConfirm {
    return Intl.message(
      'Cancel alarm',
      name: 'alarmsCancelConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Alarm cancelled`
  String get alarmsCancelled {
    return Intl.message(
      'Alarm cancelled',
      name: 'alarmsCancelled',
      desc: '',
      args: [],
    );
  }

  /// `Could not cancel the alarm.`
  String get alarmsCancelFailed {
    return Intl.message(
      'Could not cancel the alarm.',
      name: 'alarmsCancelFailed',
      desc: '',
      args: [],
    );
  }

  /// `Could not load the alarms.`
  String get alarmsLoadFailed {
    return Intl.message(
      'Could not load the alarms.',
      name: 'alarmsLoadFailed',
      desc: '',
      args: [],
    );
  }

  /// `Retry`
  String get alarmsRetry {
    return Intl.message('Retry', name: 'alarmsRetry', desc: '', args: []);
  }

  /// `Stop`
  String get alarmsStop {
    return Intl.message('Stop', name: 'alarmsStop', desc: '', args: []);
  }

  /// `Snooze 5 min`
  String get alarmsSnooze {
    return Intl.message(
      'Snooze 5 min',
      name: 'alarmsSnooze',
      desc: '',
      args: [],
    );
  }

  /// `Skip`
  String get onboardingSkip {
    return Intl.message('Skip', name: 'onboardingSkip', desc: '', args: []);
  }

  /// `Next`
  String get onboardingNext {
    return Intl.message('Next', name: 'onboardingNext', desc: '', args: []);
  }

  /// `Get started`
  String get onboardingDone {
    return Intl.message(
      'Get started',
      name: 'onboardingDone',
      desc: '',
      args: [],
    );
  }

  /// `Welcome to n8n Connect`
  String get onboardingWelcomeTitle {
    return Intl.message(
      'Welcome to n8n Connect',
      name: 'onboardingWelcomeTitle',
      desc: '',
      args: [],
    );
  }

  /// `Use on your phone the apps you build with n8n workflows. Change a workflow and the app updates right away, with nothing new to install.`
  String get onboardingWelcomeBody {
    return Intl.message(
      'Use on your phone the apps you build with n8n workflows. Change a workflow and the app updates right away, with nothing new to install.',
      name: 'onboardingWelcomeBody',
      desc: '',
      args: [],
    );
  }

  /// `Connect your server`
  String get onboardingServerTitle {
    return Intl.message(
      'Connect your server',
      name: 'onboardingServerTitle',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with your account and enter the address of your n8n. Only accounts allowed on your server can get in, and every request carries a signed session.`
  String get onboardingServerBody {
    return Intl.message(
      'Sign in with your account and enter the address of your n8n. Only accounts allowed on your server can get in, and every request carries a signed session.',
      name: 'onboardingServerBody',
      desc: '',
      args: [],
    );
  }

  /// `Your apps, built in n8n`
  String get onboardingAppsTitle {
    return Intl.message(
      'Your apps, built in n8n',
      name: 'onboardingAppsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Each app is a workflow that draws screens with forms, lists and live dashboards. When you tap a button, the workflow gets the data and replies.`
  String get onboardingAppsBody {
    return Intl.message(
      'Each app is a workflow that draws screens with forms, lists and live dashboards. When you tap a button, the workflow gets the data and replies.',
      name: 'onboardingAppsBody',
      desc: '',
      args: [],
    );
  }

  /// `Actions on your phone`
  String get onboardingActionsTitle {
    return Intl.message(
      'Actions on your phone',
      name: 'onboardingActionsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Workflows can set alarms, add calendar events, open maps, notify you or share content. They only run without asking if you allow it in Settings or in each app.`
  String get onboardingActionsBody {
    return Intl.message(
      'Workflows can set alarms, add calendar events, open maps, notify you or share content. They only run without asking if you allow it in Settings or in each app.',
      name: 'onboardingActionsBody',
      desc: '',
      args: [],
    );
  }

  /// `Notifications and permissions`
  String get onboardingPermissionsTitle {
    return Intl.message(
      'Notifications and permissions',
      name: 'onboardingPermissionsTitle',
      desc: '',
      args: [],
    );
  }

  /// `n8n can reach you even when the app is closed. Location is only requested when an app needs it, and you can change permissions in your phone's settings.`
  String get onboardingPermissionsBody {
    return Intl.message(
      'n8n can reach you even when the app is closed. Location is only requested when an app needs it, and you can change permissions in your phone\'s settings.',
      name: 'onboardingPermissionsBody',
      desc: '',
      args: [],
    );
  }

  /// `Page {current} of {total}`
  String onboardingPageLabel(int current, int total) {
    return Intl.message(
      'Page $current of $total',
      name: 'onboardingPageLabel',
      desc: '',
      args: [current, total],
    );
  }

  /// `View the tutorial`
  String get settingsTutorialTile {
    return Intl.message(
      'View the tutorial',
      name: 'settingsTutorialTile',
      desc: '',
      args: [],
    );
  }

  /// `About n8n Connect`
  String get settingsAboutTile {
    return Intl.message(
      'About n8n Connect',
      name: 'settingsAboutTile',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'es'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
