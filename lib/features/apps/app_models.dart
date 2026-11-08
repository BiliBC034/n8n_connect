import '../../core/app_config.dart';
import '../../core/json.dart';
import '../actions/action_spec.dart';
import '../server/n8n_api.dart';

/// Entry of the app catalog (`GET n8n-connect/apps`, rows of nc_apps).
class AppSummary {
  const AppSummary({
    required this.id,
    required this.name,
    required this.path,
    this.description = '',
    this.icon = 'apps',
    this.color = '',
  });

  static AppSummary? fromJson(Object? json) {
    final map = asMap(json);
    final id = asString(map['id']);
    final path = asString(map['path']);
    if (id == null || id.isEmpty || path == null || path.isEmpty) return null;
    return AppSummary(
      id: id,
      name: asString(map['name']) ?? id,
      path: path,
      description: asString(map['description']) ?? '',
      icon: asString(map['icon']) ?? 'apps',
      color: asString(map['color']) ?? '',
    );
  }

  final String id;
  final String name;

  /// Webhook path (relative to /webhook/) that returns the [AppSpec].
  final String path;
  final String description;
  final String icon;
  final String color;
}

class ScreenSpec {
  const ScreenSpec({
    required this.id,
    required this.title,
    required this.components,
  });

  final String id;
  final String? title;
  final List<Map<String, dynamic>> components;
}

/// UI description returned by an app's GET webhook (schema 1):
/// `{"schema": 1, "title", "start", "state": {...}, "screens": [...]}`.
class AppSpec {
  const AppSpec({
    required this.title,
    required this.start,
    required this.initialState,
    required this.screens,
    this.refreshSeconds,
  });

  /// Smallest `refreshSeconds` honored; shorter values are ignored.
  static const int minRefreshSeconds = 10;

  /// Throws [N8nApiException] (`unsupported_spec` / `bad_spec`).
  factory AppSpec.fromJson(Map<String, dynamic> json) {
    final schema = asInt(json['schema']) ?? 1;
    if (schema > AppConfig.specSchemaVersion) {
      throw const N8nApiException('unsupported_spec');
    }

    final screens = <String, ScreenSpec>{};
    final rawScreens = json['screens'];
    final entries = rawScreens is Map
        ? rawScreens.entries.map((e) => {...asMap(e.value), 'id': e.key})
        : asList(rawScreens).map(asMap);
    for (final raw in entries) {
      final id = asString(raw['id']);
      if (id == null || id.isEmpty) continue;
      screens[id] = ScreenSpec(
        id: id,
        title: asString(raw['title']),
        components: asList(raw['components']).map(asMap).toList(),
      );
    }
    if (screens.isEmpty) throw const N8nApiException('bad_spec');

    final start = asString(json['start']);
    final refresh = asInt(json['refreshSeconds']);
    return AppSpec(
      title: asString(json['title']) ?? '',
      start: start != null && screens.containsKey(start)
          ? start
          : screens.keys.first,
      initialState: Map<String, dynamic>.from(asMap(json['state'])),
      screens: screens,
      refreshSeconds: refresh != null && refresh >= minRefreshSeconds
          ? refresh
          : null,
    );
  }

  final String title;
  final String start;
  final Map<String, dynamic> initialState;
  final Map<String, ScreenSpec> screens;

  /// Seconds between silent reloads of this spec (`refreshSeconds`), or null.
  final int? refreshSeconds;

  ScreenSpec screen(String id) => screens[id] ?? screens[start]!;
}

/// Answer of a `submit` webhook. Every field is optional:
/// `{"message", "state": {...}, "screen", "actions": [...], "spec": {...}}`.
class ActionResponse {
  const ActionResponse({
    this.message,
    this.state = const {},
    this.screen,
    this.actions = const [],
    this.spec,
  });

  factory ActionResponse.fromJson(Map<String, dynamic> json) {
    final rawSpec = json['spec'];
    return ActionResponse(
      message: asString(json['message']),
      state: asMap(json['state']),
      screen: asString(json['screen']),
      actions: ActionSpec.listFrom(json['actions']),
      spec: rawSpec is Map ? AppSpec.fromJson(asMap(rawSpec)) : null,
    );
  }

  final String? message;
  final Map<String, dynamic> state;
  final String? screen;
  final List<ActionSpec> actions;

  /// Replaces the whole app UI when present.
  final AppSpec? spec;
}
