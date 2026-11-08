import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'selectedLocale';
  late SharedPreferences _prefs;
  Locale? _locale;

  Locale? get locale => _locale;

  // No longer a singleton, managed by Provider
  LocaleService() {
    // Load locale is now called explicitly after initialization
  }

  // Loads the saved locale
  Future<void> loadLocale() async {
    _prefs = await SharedPreferences.getInstance();
    final languageCode = _prefs.getString('${_localeKey}_languageCode');
    final countryCode = _prefs.getString('${_localeKey}_countryCode');

    if (languageCode != null) {
      _locale = Locale(languageCode, countryCode);
    } else {
      _locale = null; // Null means: use the system locale
    }
    notifyListeners(); // Notify after loading
  }

  // Set the locale
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _prefs.setString('${_localeKey}_languageCode', locale.languageCode);
    if (locale.countryCode != null) {
      await _prefs.setString('${_localeKey}_countryCode', locale.countryCode!);
    } else {
      await _prefs.remove('${_localeKey}_countryCode');
    }
    notifyListeners(); // Notify the change
  }

  // Reset to device locale
  Future<void> useDeviceLocale() async {
    if (_locale == null) return; // Already using the system locale
    _locale = null;
    await _prefs.remove('${_localeKey}_languageCode');
    await _prefs.remove('${_localeKey}_countryCode');
    notifyListeners(); // Notify the change
  }

  Locale? getSupportedLocale(Locale? locale, List<Locale> supportedLocales) {
    if (locale == null) return null; // Use system default

    // First try for an exact match with country code
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode &&
          supportedLocale.countryCode == locale.countryCode) {
        return supportedLocale;
      }
    }

    // Then try for a match just with language code
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }

    // If no match, fallback to English or the first supported locale
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == 'en') {
        return supportedLocale;
      }
    }

    return supportedLocales.first;
  }
}
