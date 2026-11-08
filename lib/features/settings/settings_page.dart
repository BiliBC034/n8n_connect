import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/log.dart';
import '../../generated/l10n.dart';
import '../auth/auth_service.dart';
import '../automation/automation_consent.dart';
import '../onboarding/onboarding_service.dart';
import '../push/push_service.dart';
import '../server/error_messages.dart';
import '../server/server_session.dart';
import '../startup/brand.dart';
import 'locale_service.dart';
import 'theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();

  bool _isEmailPasswordUser = false;
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _currentUser = Provider.of<AuthService>(
      context,
      listen: false,
    ).getCurrentUser();
    if (_currentUser != null) {
      _nameController.text = _currentUser!.displayName ?? '';
      // Check if the user has an email/password provider linked
      _isEmailPasswordUser = _currentUser!.providerData.any(
        (userInfo) => userInfo.providerId == EmailAuthProvider.PROVIDER_ID,
      );
    }
  }

  /// Reads the app version shown in the "About" entry.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (e) {
      appLog('Settings', 'could not read the app version: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
      ),
    );
  }

  Future<void> _updateDisplayName() async {
    final l10n = AppLocalizations.of(context);
    if (_nameController.text.isEmpty) {
      _showSnackBar(l10n.errorRequiredField, isError: true);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    String? error = await Provider.of<AuthService>(
      context,
      listen: false,
    ).updateUserDisplayName(_nameController.text.trim());

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (error == null) {
        _successMessage = l10n.successDisplayNameUpdated;
        // Refresh user data locally
        _currentUser = Provider.of<AuthService>(
          context,
          listen: false,
        ).getCurrentUser();
        _showSnackBar(_successMessage!);
      } else {
        _errorMessage = l10n.errorUpdateDisplayName;
        _showSnackBar(_errorMessage!, isError: true);
      }
    });
  }

  Future<void> _updatePassword() async {
    final l10n = AppLocalizations.of(context);
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar(l10n.errorRequiredField, isError: true);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar(l10n.errorPasswordsDoNotMatch, isError: true);
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _showSnackBar(l10n.errorPasswordTooShort, isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    String? error = await Provider.of<AuthService>(context, listen: false)
        .updateUserPassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (error == null) {
        _successMessage = l10n.successPasswordUpdated;
        _showSnackBar(_successMessage!);
        // Clear password fields after success
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        // Provide more specific error if possible, otherwise generic
        _errorMessage = error.contains('re-authentication')
            ? l10n.errorReauthenticationFailed(error)
            : l10n.errorUpdatePassword;
        _showSnackBar(_errorMessage!, isError: true);
      }
    });
  }

  Future<void> _confirmDeleteAccount() async {
    if (!_isEmailPasswordUser) {
      // For non-email users (like Google Sign-In), prompt directly
      _showDeleteConfirmationDialog();
    } else {
      // For email users, prompt for password
      _showDeletePasswordDialog();
    }
  }

  void _showDeleteConfirmationDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsDeleteAccountTile),
        content: Text(l10n.settingsConfirmDeleteNoPasswordPrompt), // Localized
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: Text(
              l10n.deleteButton,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeletePasswordDialog() {
    final l10n = AppLocalizations.of(context);
    _deletePasswordController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsConfirmDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsConfirmDeletePasswordPrompt),
            const SizedBox(height: 16),
            TextField(
              controller: _deletePasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsCurrentPasswordLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () {
              if (_deletePasswordController.text.isNotEmpty) {
                Navigator.pop(context);
                _deleteAccount(password: _deletePasswordController.text);
              } else {
                // Optionally show a small error within the dialog
                appLog('Settings', 'Password required');
              }
            },
            child: Text(
              l10n.settingsConfirmDeleteButton,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount({String? password}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    // Unregister this device from the n8n server while the session is valid.
    await context.read<ServerSession>().disconnect();
    if (!mounted) return;
    String? error = await Provider.of<AuthService>(
      context,
      listen: false,
    ).deleteUserAccount(currentPassword: password);

    // GoRouter's refreshListenable will handle navigation automatically
    // when the auth state changes after successful deletion.
    // We just need to handle the error case.
    if (error != null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Provide more specific error if possible
        _errorMessage = error == 'requires-recent-login'
            ? l10n.errorRequiresRecentLogin
            : l10n.errorDeleteAccount;
        _showSnackBar(_errorMessage!, isError: true);
      });
    } else {
      // Success: Auth state will change, GoRouter will redirect.
      // Optionally show a success message before the redirect happens.
      if (mounted) {
        _showSnackBar(l10n.successAccountDeleted);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    // Stop pushes to this device before dropping the Firebase session.
    await context.read<ServerSession>().disconnect();
    if (!mounted) return;
    await Provider.of<AuthService>(context, listen: false).signOut();
    // GoRouter's refreshListenable will handle navigation automatically.
    // If the widget is still mounted briefly after sign out, stop showing loading.
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Shows the language selection dialog
  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context);
    final localeService = Provider.of<LocaleService>(
      context,
      listen: false,
    ); // Get from Provider
    final supportedLocales = AppLocalizations.delegate.supportedLocales;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.languageTitle),
        content: RadioGroup<Locale?>(
          groupValue: localeService.locale,
          onChanged: (value) {
            if (value == null) {
              localeService.useDeviceLocale();
            } else {
              localeService.setLocale(value);
            }
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Option to use the device language
              RadioListTile<Locale?>(
                title: Text(l10n.useDeviceLanguage),
                value: null,
              ),
              // Options for each supported language
              ...supportedLocales.map((locale) {
                String languageName;
                // Human-readable names for the supported locales
                switch (locale.languageCode) {
                  case 'en':
                    languageName = l10n.englishLanguage;
                    break;
                  case 'es':
                    languageName = l10n.spanishLanguage;
                    break;
                  default:
                    languageName = locale.toLanguageTag();
                }
                return RadioListTile<Locale?>(
                  title: Text(languageName),
                  value: locale,
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
        ],
      ),
    );
  }

  // Shows the theme selection dialog
  void _showThemeDialog() {
    final l10n = AppLocalizations.of(context);
    final themeService = Provider.of<ThemeService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.themeSettings),
        content: RadioGroup<ThemeMode>(
          groupValue: themeService.themeMode,
          onChanged: (value) {
            if (value != null) {
              themeService.setThemeMode(value);
              Navigator.pop(context);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(l10n.lightTheme),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.darkTheme),
                value: ThemeMode.dark,
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.systemTheme),
                value: ThemeMode.system,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context); // Get localizations
    // Re-fetch user in build in case of updates like display name change
    _currentUser = context
        .watch<AuthService>()
        .getCurrentUser(); // Use watch for auth changes
    final themeService = context.watch<ThemeService>();
    final localeService = context.watch<LocaleService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: _currentUser == null
          ? Center(
              child: Text(l10n.userNotLoaded),
            ) // Should not happen if navigated correctly
          : Stack(
              // Use Stack to show loading indicator over the content
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: <Widget>[
                      const _ServerSection(),
                      const Divider(),
                      const _AutomationSection(),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: Text(l10n.settingsEmailLabel),
                        subtitle: Text(_currentUser!.email ?? 'Not available'),
                      ),
                      const Divider(),

                      // --- Display Name ---
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(l10n.settingsDisplayNameLabel),
                        subtitle: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: l10n.settingsDisplayNameHint,
                          ),
                          enabled: !_isLoading,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.save),
                          tooltip: l10n.settingsSaveNameTooltip,
                          onPressed: _isLoading ? null : _updateDisplayName,
                        ),
                      ),
                      const Divider(),

                      // --- Language ---
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(l10n.languageSettings),
                        subtitle: Text(
                          localeService.locale == null
                              ? l10n.useDeviceLanguage
                              : (localeService.locale?.languageCode == 'es'
                                    ? l10n.spanishLanguage
                                    : l10n.englishLanguage),
                        ),
                        onTap: _isLoading ? null : _showLanguageDialog,
                      ),
                      const Divider(),

                      // --- Theme ---
                      ListTile(
                        leading: const Icon(
                          Icons.brightness_6_outlined,
                        ), // Theme icon
                        title: Text(l10n.themeSettings),
                        subtitle: Text(
                          // Show the current mode
                          themeService.themeMode == ThemeMode.light
                              ? l10n.lightTheme
                              : themeService.themeMode == ThemeMode.dark
                              ? l10n.darkTheme
                              : l10n.systemTheme,
                        ),
                        onTap: _isLoading ? null : _showThemeDialog,
                      ),
                      const Divider(),

                      // --- Change Password (only for email/password users) ---
                      if (_isEmailPasswordUser) ...[
                        ExpansionTile(
                          leading: const Icon(Icons.lock),
                          title: Text(l10n.settingsChangePasswordTile),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _currentPasswordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText:
                                          l10n.settingsCurrentPasswordLabel,
                                    ),
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _newPasswordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: l10n.settingsNewPasswordLabel,
                                    ),
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText:
                                          l10n.settingsConfirmNewPasswordLabel,
                                    ),
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _updatePassword,
                                    child: Text(
                                      l10n.settingsUpdatePasswordButton,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],

                      // --- Tutorial and about ---
                      ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: Text(l10n.settingsTutorialTile),
                        onTap: _isLoading
                            ? null
                            : () => context.read<OnboardingService>().reset(),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const ExcludeSemantics(
                          child: BrandMark(size: 32),
                        ),
                        title: Text(l10n.settingsAboutTile),
                        subtitle: _version == null ? null : Text(_version!),
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: l10n.appTitle,
                          applicationVersion: _version,
                          applicationIcon: const ExcludeSemantics(
                            child: BrandMark(size: 48),
                          ),
                          applicationLegalese: '© 2025-2026 BiliBC034 · MIT',
                        ),
                      ),
                      const Divider(),

                      // --- Sign Out ---
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: Text(l10n.settingsSignOutTile),
                        onTap: _isLoading ? null : _signOut,
                      ),
                      const Divider(),

                      // --- Delete Account ---
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          l10n.settingsDeleteAccountTile,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onTap: _isLoading ? null : _confirmDeleteAccount,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // Loading Indicator Overlay
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}

/// Connection with the n8n server: status, re-sync, change and disconnect,
/// plus how pushes from n8n are handled on this device.
class _ServerSection extends StatefulWidget {
  const _ServerSection();

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  bool _busy = false;

  Future<void> _resync() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<ServerSession>().refresh();
      messenger.showSnackBar(SnackBar(content: Text(l10n.serverResyncDone)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.watch<ServerSession>();
    final push = context.read<PushService>();
    final user = session.user;
    final device = session.device;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(l10n.serverSectionTitle),
          subtitle: Text(
            session.isConnected
                ? '${session.serverName ?? ''}\n${session.baseUrl}'
                : l10n.serverNotConnected,
          ),
          isThreeLine: session.isConnected,
        ),
        if (user != null)
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(user.email),
            subtitle: Text(l10n.serverRole(user.role)),
          ),
        if (session.isConnected)
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(l10n.serverResync),
            subtitle: Text(l10n.serverResyncHint),
            enabled: !_busy,
            onTap: _resync,
          ),
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: Text(l10n.serverChange),
          enabled: !_busy,
          onTap: () => context.push('/connect'),
        ),
        if (session.isConnected)
          ListTile(
            leading: const Icon(Icons.link_off),
            title: Text(l10n.disconnectButton),
            enabled: !_busy,
            onTap: () => context.read<ServerSession>().disconnect(),
          ),
        SwitchListTile(
          secondary: const Icon(Icons.bolt),
          title: Text(l10n.pushAutoRunTitle),
          subtitle: Text(l10n.pushAutoRunHint),
          value: push.autoRun,
          onChanged: (value) async {
            await push.setAutoRun(value);
            if (mounted) setState(() {});
          },
        ),
        if (device != null)
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: Text(device.name),
            subtitle: Text(l10n.deviceIdLabel(device.id.substring(0, 8))),
          ),
      ],
    );
  }
}

/// Apps allowed to run actions on this phone without asking, for the
/// connected server, plus the alarm list.
class _AutomationSection extends StatefulWidget {
  const _AutomationSection();

  @override
  State<_AutomationSection> createState() => _AutomationSectionState();
}

class _AutomationSectionState extends State<_AutomationSection> {
  Uri? _server;
  List<String> _apps = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final server = context.watch<ServerSession>().baseUrl;
    if (server != _server) {
      _server = server;
      _load();
    }
  }

  Future<void> _load() async {
    final server = _server;
    final apps = server == null
        ? <String>[]
        : await AutomationConsent.allowedApps(server);
    if (mounted && server == _server) setState(() => _apps = apps);
  }

  Future<void> _revoke(String appId) async {
    final server = _server;
    if (server == null) return;
    await AutomationConsent.setAllowed(server, appId, false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.bolt),
          title: Text(l10n.permAutomationsTitle),
        ),
        if (_apps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.permAutomationsHint),
          )
        else
          for (final app in _apps)
            SwitchListTile(
              title: Text(app),
              value: true,
              onChanged: (value) {
                if (!value) _revoke(app);
              },
            ),
        ListTile(
          leading: const Icon(Icons.alarm),
          title: Text(l10n.permAlarmsTile),
          onTap: () => context.push('/alarms'),
        ),
      ],
    );
  }
}
