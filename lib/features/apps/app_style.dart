import 'package:flutter/material.dart';

/// Material icon names that specs and the app catalog may use. Icons are
/// tree-shaken, so only names listed here can be resolved at runtime.
const Map<String, IconData> _icons = {
  'add': Icons.add,
  'alarm': Icons.alarm,
  'alarm_add': Icons.alarm_add,
  'apps': Icons.apps,
  'arrow_back': Icons.arrow_back,
  'arrow_forward': Icons.arrow_forward,
  'bolt': Icons.bolt,
  'calendar_today': Icons.calendar_today,
  'camera': Icons.camera_alt,
  'check': Icons.check,
  'check_circle': Icons.check_circle,
  'close': Icons.close,
  'cloud': Icons.cloud,
  'delete': Icons.delete,
  'directions_car': Icons.directions_car,
  'edit': Icons.edit,
  'email': Icons.email,
  'error': Icons.error,
  'event': Icons.event,
  'event_available': Icons.event_available,
  'favorite': Icons.favorite,
  'fitness_center': Icons.fitness_center,
  'home': Icons.home,
  'info': Icons.info,
  'lightbulb': Icons.lightbulb,
  'link': Icons.link,
  'list': Icons.list,
  'local_cafe': Icons.local_cafe,
  'location_on': Icons.location_on,
  'lock': Icons.lock,
  'music_note': Icons.music_note,
  'notifications': Icons.notifications,
  'person': Icons.person,
  'phone': Icons.phone,
  'play_arrow': Icons.play_arrow,
  'power': Icons.power_settings_new,
  'refresh': Icons.refresh,
  'restaurant': Icons.restaurant,
  'schedule': Icons.schedule,
  'search': Icons.search,
  'send': Icons.send,
  'settings': Icons.settings,
  'shopping_cart': Icons.shopping_cart,
  'star': Icons.star,
  'stop': Icons.stop,
  'thermostat': Icons.thermostat,
  'timer': Icons.timer,
  'warning': Icons.warning,
  'wb_sunny': Icons.wb_sunny,
  'work': Icons.work,
};

IconData? iconByName(String? name) => name == null ? null : _icons[name];

/// `#RRGGBB` or `#AARRGGBB`.
Color? parseHexColor(String? value) {
  if (value == null) return null;
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}
