import 'package:flutter/foundation.dart';

/// Tagged debug log. Never pass tokens or other secrets here.
void appLog(String tag, Object? message) {
  debugPrint('[$tag] $message');
}
