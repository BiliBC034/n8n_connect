// Lenient readers for JSON written by hand in n8n workflows, where numbers and
// booleans often arrive as strings ("7", "true").

String? asString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.isFinite ? value.toInt() : null;
  if (value is String) {
    final text = value.trim();
    final parsed = int.tryParse(text);
    if (parsed != null) return parsed;
    final decimal = double.tryParse(text);
    return decimal != null && decimal.isFinite ? decimal.toInt() : null;
  }
  return null;
}

/// Null for non-finite values (NaN, Infinity) too.
double? asDouble(Object? value) {
  final result = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.trim().replaceAll(',', '.'))
      : null;
  return result != null && result.isFinite ? result : null;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
      case '':
        return false;
    }
  }
  return fallback;
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v));
  }
  return <String, dynamic>{};
}

List<dynamic> asList(Object? value) => value is List ? value : const [];
