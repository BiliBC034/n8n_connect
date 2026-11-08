import 'json.dart';

/// `{{key}}` placeholders resolved against an app's state.
///
/// Keys may be dotted paths (`{{user.name}}`). A string that is exactly one
/// placeholder resolves to the raw value, so `"{{hour}}"` keeps an int as an
/// int when used as an action parameter.
class Template {
  Template._();

  static final RegExp _placeholder = RegExp(r'\{\{\s*([\w.$-]+)\s*\}\}');

  static Object? lookup(Map<String, dynamic> state, String path) {
    Object? current = state;
    for (final part in path.split('.')) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  static String render(String input, Map<String, dynamic> state) {
    if (!input.contains('{{')) return input;
    return input.replaceAllMapped(
      _placeholder,
      (match) => asString(lookup(state, match.group(1)!)) ?? '',
    );
  }

  /// Resolves placeholders inside strings, maps and lists.
  static Object? resolve(Object? value, Map<String, dynamic> state) {
    if (value is String) {
      final whole = _placeholder.matchAsPrefix(value.trim());
      if (whole != null && whole.end == value.trim().length) {
        return lookup(state, whole.group(1)!);
      }
      return render(value, state);
    }
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), resolve(v, state)));
    }
    if (value is List) {
      return value.map((v) => resolve(v, state)).toList();
    }
    return value;
  }

  /// Truthiness for `visible` conditions: null, false, '', 0, "false", "0"
  /// and empty collections are false.
  static bool truthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return asBool(value, fallback: true);
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }
}
