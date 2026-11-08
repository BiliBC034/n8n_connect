import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log.dart';
import '../server/session_store.dart';

/// Whether the first-run tutorial has been seen.
///
/// The router sends the user to the tutorial while [done] is false. Starts
/// as false; call [load] before the router is created.
class OnboardingService extends ChangeNotifier {
  static const String _doneKey = 'onboarding_done';

  bool _done = false;

  /// True once the tutorial was finished or skipped.
  bool get done => _done;

  /// Reads the saved state. If the read fails, the tutorial is treated as
  /// done so that it never blocks the app.
  ///
  /// Users who updated the app already have a server configured and no
  /// tutorial flag yet. For them the tutorial counts as seen, so it does not
  /// appear after an update. An explicit `false` (the tutorial was asked for
  /// from Settings) is kept as is.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_doneKey);
      if (saved != null) {
        _done = saved;
      } else if ((prefs.getString(SessionStore.lastUrlKey) ?? '').isNotEmpty) {
        _done = true;
        await prefs.setBool(_doneKey, true);
      } else {
        _done = false;
      }
    } catch (e) {
      appLog('Onboarding', 'could not read tutorial state: $e');
      _done = true;
    }
    notifyListeners();
  }

  /// Marks the tutorial as seen. The state changes at once; the save is
  /// best effort.
  Future<void> complete() => _setDone(true);

  /// Shows the tutorial again the next time the router runs.
  Future<void> reset() => _setDone(false);

  Future<void> _setDone(bool value) async {
    _done = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_doneKey, value);
    } catch (e) {
      appLog('Onboarding', 'could not save tutorial state: $e');
    }
  }
}
