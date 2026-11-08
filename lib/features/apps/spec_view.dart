import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/json.dart';
import '../../core/template.dart';
import '../../generated/l10n.dart';
import '../actions/action_spec.dart';
import '../automation/automation_switch.dart';
import '../device_context/device_context.dart';
import '../device_context/permission_tile.dart';
import 'app_style.dart';

typedef StateChanged = void Function(String key, Object? value);
typedef ActionsRequested = Future<void> Function(List<ActionSpec> actions);

/// Renders the components of one spec screen. Stateless: values live in the
/// app state map owned by the runner page.
class SpecView extends StatelessWidget {
  const SpecView({
    super.key,
    required this.components,
    required this.state,
    required this.onChanged,
    required this.onActions,
    this.enabled = true,
    this.appId,
  });

  final List<Map<String, dynamic>> components;
  final Map<String, dynamic> state;
  final StateChanged onChanged;
  final ActionsRequested onActions;

  /// False while a submit is running.
  final bool enabled;

  /// App being shown, for per-app settings such as `automation`.
  final String? appId;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final component in components) {
      if (!_isVisible(component)) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _component(context, component),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  String _text(Map<String, dynamic> c, String field) =>
      Template.render(asString(c[field]) ?? '', state);

  /// False when `visible` resolves to a falsy value; no `visible` means shown.
  bool _isVisible(Map<String, dynamic> c) =>
      !c.containsKey('visible') ||
      Template.truthy(Template.resolve(c['visible'], state));

  /// Numeric field, resolved through templates. Null when missing or invalid.
  double? _number(Object? raw) =>
      _finite(asDouble(Template.resolve(raw, state)));

  /// Options of a multi-option control. Entries without `value` are ignored.
  List<Map<String, dynamic>> _options(Map<String, dynamic> c) =>
      asList(c['options']).map(asMap).where((o) {
        return asString(o['value']) != null;
      }).toList();

  String _optionLabel(Map<String, dynamic> o) => Template.render(
    asString(o['label']) ?? asString(o['value']) ?? '',
    state,
  );

  bool _optionEnabled(Map<String, dynamic> o) =>
      enabled && !asBool(o['disabled']);

  Widget _component(BuildContext context, Map<String, dynamic> c) {
    final type = asString(c['type']) ?? '';
    switch (type) {
      case 'text':
        return _textComponent(context, c);
      case 'banner':
        return _banner(context, c);
      case 'card':
        return _card(context, c);
      case 'image':
        return _image(c);
      case 'divider':
        return const Divider();
      case 'spacer':
        return SizedBox(
          height: (asInt(c['height']) ?? 16).clamp(0, 2000).toDouble(),
        );
      case 'input':
        final key = asString(c['key']);
        if (key == null) return const SizedBox.shrink();
        return _SpecTextField(
          fieldKey: key,
          value: asString(state[key]) ?? '',
          label: _text(c, 'label'),
          hint: _text(c, 'hint'),
          keyboard: asString(c['keyboard']) ?? 'text',
          obscure: asBool(c['obscure']),
          required: asBool(c['required']),
          enabled: enabled,
          onChanged: (value) => onChanged(key, value),
        );
      case 'switch':
        return _switch(c);
      case 'select':
        return _select(context, c);
      case 'date':
        return _datePicker(context, c);
      case 'time':
        return _timePicker(context, c);
      case 'button':
        return _button(c);
      case 'list':
        return _list(c);
      case 'details':
        return _details(context, c);
      case 'automation':
        final app = appId;
        if (app == null) return const SizedBox.shrink();
        return AutomationSwitch(
          appId: app,
          label: _text(c, 'label'),
          description: _text(c, 'description'),
        );
      case 'permission':
        final permission = DevicePermission.fromName(asString(c['permission']));
        if (permission == null) return const SizedBox.shrink();
        return PermissionTile(
          permission: permission,
          label: _text(c, 'label'),
          description: _text(c, 'description'),
        );
      case 'slider':
        return _slider(context, c);
      case 'checkbox':
        return _checkbox(c);
      case 'multiselect':
        return _multiselect(context, c);
      case 'stepper':
        return _stepper(context, c);
      case 'progress':
        return _progress(context, c);
      case 'metric':
        return _metric(context, c);
      case 'grid':
        return _grid(context, c);
      case 'table':
        return _table(c);
      default:
        return Text(
          AppLocalizations.of(context).unsupportedComponent(type),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        );
    }
  }

  Widget _textComponent(BuildContext context, Map<String, dynamic> c) {
    final theme = Theme.of(context).textTheme;
    final style = switch (asString(c['style'])) {
      'title' => theme.headlineSmall,
      'subtitle' => theme.titleMedium,
      'caption' => theme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      _ => theme.bodyLarge,
    };
    final align = switch (asString(c['align'])) {
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      _ => TextAlign.start,
    };
    return SelectableText(_text(c, 'text'), style: style, textAlign: align);
  }

  Widget _banner(BuildContext context, Map<String, dynamic> c) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = Template.render(asString(c['tone']) ?? 'info', state);
    final (
      Color background,
      Color foreground,
      IconData defaultIcon,
    ) = switch (tone) {
      'success' => (
        dark ? const Color(0xFF14361F) : const Color(0xFFE6F4EA),
        dark ? const Color(0xFF8CE0A4) : const Color(0xFF14532D),
        Icons.check_circle,
      ),
      'warning' => (
        dark ? const Color(0xFF3D2E05) : const Color(0xFFFFF4D6),
        dark ? const Color(0xFFF5D06F) : const Color(0xFF6B4A00),
        Icons.warning_amber,
      ),
      'error' => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
      _ => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            iconByName(asString(c['icon'])) ?? defaultIcon,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_text(c, 'text'), style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> c) {
    final title = _text(c, 'title');
    final subtitle = _text(c, 'subtitle');
    final children = asList(c['components']).map(asMap).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty || subtitle.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: iconByName(asString(c['icon'])) == null
                    ? null
                    : Icon(iconByName(asString(c['icon']))),
                title: title.isEmpty ? null : Text(title),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
              ),
            if (children.isNotEmpty)
              SpecView(
                components: children,
                state: state,
                onChanged: onChanged,
                onActions: onActions,
                enabled: enabled,
                appId: appId,
              ),
          ],
        ),
      ),
    );
  }

  Widget _image(Map<String, dynamic> c) {
    final url = Uri.tryParse(_text(c, 'url'));
    // Only HTTPS images: specs must not make the app fetch plain-HTTP content.
    if (url == null || url.scheme != 'https') return const SizedBox.shrink();
    final height = asInt(c['height'])?.clamp(0, 4000).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url.toString(),
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _slider(BuildContext context, Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final min = _number(c['min']) ?? 0.0;
    var max = _number(c['max']) ?? 100.0;
    if (max <= min) max = min + 1;
    final step = _number(c['step']);
    final validStep = step != null && step > 0 ? step : null;
    var divisions = validStep == null
        ? null
        : ((max - min) / validStep).round();
    // Slider needs at least one division; huge counts would paint too many ticks.
    if (divisions != null && (divisions < 1 || divisions > 1000)) {
      divisions = null;
    }
    final whole = validStep == null
        ? _isWhole(min) && _isWhole(max)
        : _isWhole(min) && _isWhole(validStep);
    final current = _within(_finite(asDouble(state[key])) ?? min, min, max);
    final unit = _text(c, 'unit');
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_text(c, 'label'), style: textTheme.labelLarge),
            ),
            Text(
              '${_formatNumber(current)}$unit',
              style: textTheme.titleMedium,
            ),
          ],
        ),
        Slider(
          value: current,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled
              ? (value) =>
                    onChanged(key, whole ? value.round() : _twoDecimals(value))
              : null,
        ),
      ],
    );
  }

  Widget _checkbox(Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final description = _text(c, 'description');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_text(c, 'label')),
      subtitle: description.isEmpty ? null : Text(description),
      value: asBool(state[key]),
      onChanged: enabled ? (value) => onChanged(key, value ?? false) : null,
    );
  }

  Widget _multiselect(BuildContext context, Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final label = _text(c, 'label');
    final options = _options(c);
    final values = [for (final o in options) asString(o['value']) ?? ''];
    // Option order decides the order of the stored list.
    final order = values.toSet();
    final selected = asList(
      state[key],
    ).map(asString).whereType<String>().toSet();

    void toggle(String value) {
      final next = <String>{...selected};
      if (!next.remove(value)) next.add(value);
      onChanged(key, [
        for (final v in order)
          if (next.contains(v)) v,
        for (final v in next)
          if (!order.contains(v)) v,
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < options.length; i++)
              FilterChip(
                label: Text(_optionLabel(options[i])),
                selected: selected.contains(values[i]),
                onSelected: _optionEnabled(options[i])
                    ? (_) => toggle(values[i])
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepper(BuildContext context, Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final min = _number(c['min']);
    final max = _number(c['max']);
    final step = _number(c['step']);
    final delta = step != null && step > 0 ? step : 1.0;
    final current = _within(
      _finite(asDouble(state[key])) ?? min ?? 0.0,
      min,
      max,
    );
    final canDecrease = enabled && (min == null || current > min);
    final canIncrease = enabled && (max == null || current < max);
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    void change(double direction) {
      final value = _within(current + direction * delta, min, max);
      onChanged(
        key,
        _isWhole(delta) && _isWhole(value)
            ? value.round()
            : _twoDecimals(value),
      );
    }

    return Row(
      children: [
        Expanded(child: Text(_text(c, 'label'), style: textTheme.bodyLarge)),
        IconButton(
          tooltip: l10n.compDecrease,
          onPressed: canDecrease ? () => change(-1) : null,
          icon: const Icon(Icons.remove),
        ),
        Text(_formatNumber(current), style: textTheme.titleMedium),
        IconButton(
          tooltip: l10n.compIncrease,
          onPressed: canIncrease ? () => change(1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _progress(BuildContext context, Map<String, dynamic> c) {
    final value = _number(c['value']) ?? 0.0;
    final total = _number(c['max']) ?? (value > 1 ? 100.0 : 1.0);
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0).toDouble();
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_text(c, 'label'), style: textTheme.labelLarge),
            ),
            Text('${(ratio * 100).round()}%', style: textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: ratio),
      ],
    );
  }

  Widget _metric(BuildContext context, Map<String, dynamic> c) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final tone = Template.render(asString(c['tone']) ?? 'info', state);
    final valueColor = switch (tone) {
      'success' => dark ? const Color(0xFF8CE0A4) : const Color(0xFF1B7F3B),
      'warning' => dark ? const Color(0xFFFFC857) : const Color(0xFFB26A00),
      'error' => scheme.error,
      _ => null,
    };
    final icon = iconByName(asString(c['icon']));
    final unit = _text(c, 'unit');
    final caption = _text(c, 'caption');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(_text(c, 'label'), style: textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 4,
              children: [
                Text(
                  _text(c, 'value'),
                  style: textTheme.headlineSmall?.copyWith(color: valueColor),
                ),
                if (unit.isNotEmpty) Text(unit, style: textTheme.titleMedium),
              ],
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  caption,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Components in rows of equal-width columns (1 to 4), 12 px apart.
  Widget _grid(BuildContext context, Map<String, dynamic> c) {
    final columns = (asInt(Template.resolve(c['columns'], state)) ?? 2)
        .clamp(1, 4)
        .toInt();
    final items = asList(c['components']).map(asMap).where(_isVisible).toList();
    final rows = <Widget>[];
    for (var start = 0; start < items.length; start += columns) {
      final rowItems = items.skip(start).take(columns).toList();
      if (start > 0) rows.add(const SizedBox(height: 12));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: i < rowItems.length
                      ? _component(context, rowItems[i])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  /// Read-only grid of text cells. Rows shorter than the header are padded
  /// with empty cells; longer rows are cut.
  Widget _table(Map<String, dynamic> c) {
    final headers = [
      for (final h in asList(c['columns']))
        Template.render(asString(h) ?? '', state),
    ];
    if (headers.isEmpty) return const SizedBox.shrink();
    final rows = [
      for (final row in asList(c['rows']).whereType<List>())
        [
          for (var i = 0; i < headers.length; i++)
            i < row.length
                ? Template.render(asString(row[i]) ?? '', state)
                : '',
        ],
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [for (final h in headers) DataColumn(label: Text(h))],
          rows: [
            for (final row in rows)
              DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
          ],
        ),
      ),
    );
  }

  Widget _switch(Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final description = _text(c, 'description');
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_text(c, 'label')),
      subtitle: description.isEmpty ? null : Text(description),
      value: asBool(state[key]),
      onChanged: enabled ? (value) => onChanged(key, value) : null,
    );
  }

  Widget _select(BuildContext context, Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final label = _text(c, 'label');
    final selected = asString(state[key]);
    final options = _options(c);

    switch (asString(c['style'])) {
      case 'chips':
        Map<String, dynamic>? current;
        for (final o in options) {
          if (asString(o['value']) == selected) current = o;
        }
        final description = current == null
            ? ''
            : asString(current['description']) ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  ChoiceChip(
                    label: Text(_optionLabel(o)),
                    selected: asString(o['value']) == selected,
                    onSelected: _optionEnabled(o)
                        ? (_) => onChanged(key, asString(o['value']))
                        : null,
                  ),
              ],
            ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      case 'radio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label.isNotEmpty)
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            for (final o in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: _optionEnabled(o),
                leading: Icon(
                  asString(o['value']) == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_optionLabel(o)),
                subtitle: asString(o['description']) == null
                    ? null
                    : Text(asString(o['description'])!),
                onTap: () => onChanged(key, asString(o['value'])),
              ),
          ],
        );
      default:
        final values = options.map((o) => asString(o['value'])!).toSet();
        return DropdownButtonFormField<String>(
          initialValue: values.contains(selected) ? selected : null,
          decoration: InputDecoration(
            labelText: label.isEmpty ? null : label,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: asString(o['value']),
                enabled: !asBool(o['disabled']),
                child: Text(_optionLabel(o)),
              ),
          ],
          onChanged: enabled ? (value) => onChanged(key, value) : null,
        );
    }
  }

  Widget _datePicker(BuildContext context, Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final value = DateTime.tryParse(asString(state[key]) ?? '');
    final localizations = MaterialLocalizations.of(context);
    return _PickerTile(
      icon: Icons.calendar_today,
      label: _text(c, 'label'),
      value: value == null ? '—' : localizations.formatMediumDate(value),
      enabled: enabled,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value == null || value.year < 1900 || value.year > 2100
              ? now
              : value,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100, 12, 31),
        );
        if (picked == null) return;
        final text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
        onChanged(key, text);
      },
    );
  }

  Widget _timePicker(BuildContext context, Map<String, dynamic> c) {
    final key = asString(c['key']);
    if (key == null) return const SizedBox.shrink();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})',
    ).firstMatch(asString(state[key]) ?? '');
    final value = match == null
        ? null
        : TimeOfDay(
            hour: int.parse(match.group(1)!) % 24,
            minute: int.parse(match.group(2)!) % 60,
          );
    return _PickerTile(
      icon: Icons.schedule,
      label: _text(c, 'label'),
      value: value == null ? '—' : value.format(context),
      enabled: enabled,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked == null) return;
        onChanged(
          key,
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}',
        );
      },
    );
  }

  Widget _button(Map<String, dynamic> c) {
    final actions = ActionSpec.ofComponent(c);
    final onPressed = enabled && actions.isNotEmpty
        ? () => onActions(actions)
        : null;
    final label = Text(_text(c, 'label'));
    final icon = iconByName(asString(c['icon']));
    const padding = EdgeInsets.symmetric(vertical: 14);

    switch (asString(c['style'])) {
      case 'outlined':
        final style = OutlinedButton.styleFrom(padding: padding);
        return icon == null
            ? OutlinedButton(onPressed: onPressed, style: style, child: label)
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: style,
                icon: Icon(icon),
                label: label,
              );
      case 'text':
        return icon == null
            ? TextButton(onPressed: onPressed, child: label)
            : TextButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: label,
              );
      case 'tonal':
        final style = FilledButton.styleFrom(padding: padding);
        return icon == null
            ? FilledButton.tonal(
                onPressed: onPressed,
                style: style,
                child: label,
              )
            : FilledButton.tonalIcon(
                onPressed: onPressed,
                style: style,
                icon: Icon(icon),
                label: label,
              );
      default:
        final style = FilledButton.styleFrom(padding: padding);
        return icon == null
            ? FilledButton(onPressed: onPressed, style: style, child: label)
            : FilledButton.icon(
                onPressed: onPressed,
                style: style,
                icon: Icon(icon),
                label: label,
              );
    }
  }

  Widget _list(Map<String, dynamic> c) {
    final items = asList(c['items']).map(asMap).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in items)
            Builder(
              builder: (context) {
                final actions = ActionSpec.ofComponent(item);
                final subtitle = _text(item, 'subtitle');
                final trailing = _text(item, 'trailing');
                final icon = iconByName(asString(item['icon']));
                return ListTile(
                  leading: icon == null ? null : Icon(icon),
                  title: Text(_text(item, 'title')),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: trailing.isNotEmpty
                      ? Text(trailing)
                      : (actions.isEmpty
                            ? null
                            : const Icon(Icons.chevron_right)),
                  onTap: enabled && actions.isNotEmpty
                      ? () => onActions(actions)
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, Map<String, dynamic> c) {
    final items = asList(c['items']).map(asMap).toList();
    final theme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _text(item, 'label'),
                        style: theme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: SelectableText(
                        _text(item, 'value'),
                        style: theme.bodyLarge,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Null for NaN and infinities, which cannot be shown or clamped.
double? _finite(double? value) =>
    value != null && value.isFinite ? value : null;

/// Clamps [value] into [min]..[max]; a missing bound does not limit it.
double _within(double value, double? min, double? max) {
  if (min != null && value < min) return min;
  if (max != null && value > max) return max;
  return value;
}

bool _isWhole(double value) => value == value.roundToDouble();

/// Rounds to two decimals so float noise (0.1 + 0.2) is not stored.
double _twoDecimals(double value) => double.parse(value.toStringAsFixed(2));

/// Number text without a trailing ".0" (5 shows as 5, 2.5 as 2.5).
String _formatNumber(double value) =>
    _isWhole(value) ? value.round().toString() : _twoDecimals(value).toString();

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        enabled: enabled,
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// Text input that keeps its controller (and cursor) across rebuilds, and
/// follows external changes to the state value (e.g. `set_state`).
class _SpecTextField extends StatefulWidget {
  const _SpecTextField({
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.hint,
    required this.keyboard,
    required this.obscure,
    required this.required,
    required this.enabled,
    required this.onChanged,
  });

  final String fieldKey;
  final String value;
  final String label;
  final String hint;
  final String keyboard;
  final bool obscure;
  final bool required;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_SpecTextField> createState() => _SpecTextFieldState();
}

class _SpecTextFieldState extends State<_SpecTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _SpecTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.keyboard == 'multiline';
    final keyboardType = switch (widget.keyboard) {
      'number' => const TextInputType.numberWithOptions(decimal: true),
      'email' => TextInputType.emailAddress,
      'phone' => TextInputType.phone,
      'url' => TextInputType.url,
      'multiline' => TextInputType.multiline,
      _ => TextInputType.text,
    };
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      obscureText: widget.obscure,
      keyboardType: keyboardType,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 6 : 1,
      inputFormatters: widget.keyboard == 'number'
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))]
          : null,
      decoration: InputDecoration(
        labelText: widget.label.isEmpty
            ? null
            : (widget.required ? '${widget.label} *' : widget.label),
        hintText: widget.hint.isEmpty ? null : widget.hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
