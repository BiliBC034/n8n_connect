import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/json.dart';
import '../../core/template.dart';
import '../actions/action_spec.dart';
import 'app_style.dart';

/// Gap between nodes, both across a row and between rows of one rank.
const double flowGap = 12;

/// Narrowest and widest node box. The number of columns depends on the first.
const double flowMinNodeWidth = 132;
const double flowMaxNodeWidth = 220;

const double flowNodeHeight = 64;

/// Vertical space between two visual rows.
const double flowRowGap = 40;

/// Vertical space between two independent flows (or the loose nodes).
const double flowGroupGap = 64;

/// Room above and below the graph when it has loop (back) edges, which turn
/// around above their target and below their source.
const double flowLoopRoom = 24;

/// Side margin kept free of nodes for edge lanes: on the left for edges that
/// jump over rows, on the right for loop edges.
const double flowLaneGutter = 18;

/// How an edge is drawn.
enum FlowEdgeKind {
  /// Straight down to a later row: a single S curve.
  forward,

  /// Down to a later row through the left lane, because a curve would cross
  /// other nodes.
  lane,

  /// Closes a cycle: back up through the right lane.
  back,
}

/// One edge of a laid-out graph, identified by node ids.
class FlowEdgeLayout {
  const FlowEdgeLayout({
    required this.from,
    required this.to,
    required this.kind,
    required this.points,
  });

  final String from;
  final String to;
  final FlowEdgeKind kind;

  /// Route in graph coordinates. Starts at an output port (bottom side of the
  /// source) and ends at an input port (top side of the target). [forward]
  /// edges have only those two points and are drawn as a curve; the others
  /// are polylines whose horizontal segments run between rows.
  final List<Offset> points;

  Offset get start => points.first;
  Offset get end => points.last;
}

/// Result of [computeFlowLayout]: node boxes in graph coordinates (top-left
/// origin) plus the routed edges.
class FlowLayout {
  const FlowLayout({
    required this.nodes,
    required this.edges,
    required this.height,
  });

  /// Box of each node by id.
  final Map<String, Rect> nodes;

  /// Valid edges in input order, without duplicates.
  final List<FlowEdgeLayout> edges;

  /// Height of the whole graph, including room for loop edges.
  final double height;

  bool get hasBackEdges => edges.any((e) => e.kind == FlowEdgeKind.back);
}

/// Lays out a directed graph top to bottom in [width], with nodes
/// [nodeHeight] high. Pure Dart, no widgets.
///
/// Steps: roots (nodes without incoming edges, or the first node) start a
/// DFS; edges into nodes still on the DFS stack are back edges and are left
/// out of the layering. Rank is the longest path over the other edges. Each
/// rank is ordered by barycenter sweeps. Every independent flow (weakly
/// connected group) gets its own block, stacked in input order, with nodes
/// without edges together in a last block. Inside a block each rank is cut
/// into rows of as many nodes as the width allows.
///
/// Unknown ids in [edges] are ignored, duplicate edges count once, and
/// duplicate ids in [ids] keep their first occurrence.
FlowLayout computeFlowLayout(
  List<String> ids,
  List<(String, String)> edges,
  double width, {
  double nodeHeight = flowNodeHeight,
}) {
  final index = <String, int>{};
  final names = <String>[];
  for (final id in ids) {
    if (index.containsKey(id)) continue;
    index[id] = names.length;
    names.add(id);
  }
  final n = names.length;
  if (n == 0) {
    return const FlowLayout(nodes: {}, edges: [], height: 0);
  }

  // Valid edges in input order, without duplicates.
  final seen = <(int, int)>{};
  final pairs = <(int, int)>[];
  for (final (from, to) in edges) {
    final a = index[from];
    final b = index[to];
    if (a == null || b == null) continue;
    if (seen.add((a, b))) pairs.add((a, b));
  }

  final out = List.generate(n, (_) => <int>[]);
  final incoming = List.filled(n, 0);
  for (final (a, b) in pairs) {
    out[a].add(b);
    incoming[b]++;
  }

  // Roots: nodes without incoming edges, in input order. Fallback: first node.
  final roots = [
    for (var i = 0; i < n; i++)
      if (incoming[i] == 0) i,
  ];
  if (roots.isEmpty) roots.add(0);

  // DFS. An edge to a node still on the stack closes a cycle: a back edge.
  final state = List.filled(n, 0); // 0 new, 1 on stack, 2 done
  final backEdges = <(int, int)>{};
  void visit(int u) {
    state[u] = 1;
    for (final v in out[u]) {
      if (state[v] == 1) {
        backEdges.add((u, v));
      } else if (state[v] == 0) {
        visit(v);
      }
    }
    state[u] = 2;
  }

  for (final r in roots) {
    if (state[r] == 0) visit(r);
  }
  for (var i = 0; i < n; i++) {
    if (state[i] == 0) visit(i);
  }

  // Layering uses only the non-back edges, which form a DAG.
  final succ = List.generate(n, (_) => <int>[]);
  final pred = List.generate(n, (_) => <int>[]);
  for (final (a, b) in pairs) {
    if (backEdges.contains((a, b))) continue;
    succ[a].add(b);
    pred[b].add(a);
  }

  // Rank = longest path from the roots (Kahn order over the DAG).
  final rank = List.filled(n, 0);
  final pending = [for (var i = 0; i < n; i++) pred[i].length];
  final queue = [
    for (var i = 0; i < n; i++)
      if (pending[i] == 0) i,
  ];
  for (var q = 0; q < queue.length; q++) {
    final u = queue[q];
    for (final v in succ[u]) {
      rank[v] = math.max(rank[v], rank[u] + 1);
      if (--pending[v] == 0) queue.add(v);
    }
  }

  final maxRank = rank.reduce(math.max);
  final levels = List.generate(maxRank + 1, (_) => <int>[]);
  for (var i = 0; i < n; i++) {
    levels[rank[i]].add(i); // input order
  }

  final pos = List.filled(n, 0);
  void updatePositions(List<int> level) {
    for (var k = 0; k < level.length; k++) {
      pos[level[k]] = k;
    }
  }

  for (final level in levels) {
    updatePositions(level);
  }

  // Reorders one rank by the average position of its neighbours. Nodes
  // without neighbours keep their slot; the others are stable-sorted into the
  // slots that remain.
  void reorder(List<int> level, List<List<int>> adjacent) {
    final slots = <int>[];
    final movable = <(double, int, int)>[]; // barycenter, old slot, node
    for (var k = 0; k < level.length; k++) {
      final node = level[k];
      final neighbours = adjacent[node];
      if (neighbours.isEmpty) continue;
      var sum = 0;
      for (final v in neighbours) {
        sum += pos[v];
      }
      movable.add((sum / neighbours.length, k, node));
      slots.add(k);
    }
    if (movable.length < 2) return;
    movable.sort((x, y) {
      final byBarycenter = x.$1.compareTo(y.$1);
      return byBarycenter != 0 ? byBarycenter : x.$2.compareTo(y.$2);
    });
    for (var i = 0; i < slots.length; i++) {
      level[slots[i]] = movable[i].$3;
    }
    updatePositions(level);
  }

  // Four sweeps: down (predecessors), up (successors), down, up.
  for (var sweep = 0; sweep < 4; sweep++) {
    if (sweep.isEven) {
      for (var r = 1; r <= maxRank; r++) {
        reorder(levels[r], pred);
      }
    } else {
      for (var r = maxRank - 1; r >= 0; r--) {
        reorder(levels[r], succ);
      }
    }
  }

  // Independent flows: weakly connected groups numbered by their first node.
  // Nodes without any edge share one last group.
  final group = List.filled(n, -1);
  final neighbours = List.generate(n, (_) => <int>[]);
  for (final (a, b) in pairs) {
    neighbours[a].add(b);
    neighbours[b].add(a);
  }
  var groupCount = 0;
  final loose = <int>[];
  for (var i = 0; i < n; i++) {
    if (group[i] != -1) continue;
    if (neighbours[i].isEmpty) {
      loose.add(i);
      continue;
    }
    final id = groupCount++;
    group[i] = id;
    final stack = [i];
    while (stack.isNotEmpty) {
      for (final v in neighbours[stack.removeLast()]) {
        if (group[v] != -1) continue;
        group[v] = id;
        stack.add(v);
      }
    }
  }
  if (loose.isNotEmpty) {
    for (final i in loose) {
      group[i] = groupCount;
    }
    groupCount++;
  }

  final hasBack = backEdges.isNotEmpty;
  final w = math.max(0.0, width);
  final top = hasBack ? flowLoopRoom : 0.0;
  final rightGutter = hasBack ? flowLaneGutter : 0.0;

  // Places every node in the band [left, left + available], returning the
  // boxes by node index and the bottom of the last row.
  (List<Rect>, double) place(double left, double available) {
    final columns = math.max(
      1,
      ((available + flowGap) / (flowMinNodeWidth + flowGap)).floor(),
    );
    final rects = List.filled(n, Rect.zero);
    var y = top;
    for (var g = 0; g < groupCount; g++) {
      if (g > 0) y += flowGroupGap - flowRowGap;
      for (final level in levels) {
        final members = [
          for (final v in level)
            if (group[v] == g) v,
        ];
        for (var s = 0; s < members.length; s += columns) {
          final count = math.min(columns, members.length - s);
          final nodeWidth = math.max(
            0.0,
            math.min(
              flowMaxNodeWidth,
              (available - flowGap * (count - 1)) / count,
            ),
          );
          final rowWidth = nodeWidth * count + flowGap * (count - 1);
          final x0 = left + (available - rowWidth) / 2;
          for (var k = 0; k < count; k++) {
            rects[members[s + k]] = Rect.fromLTWH(
              x0 + k * (nodeWidth + flowGap),
              y,
              nodeWidth,
              nodeHeight,
            );
          }
          y += nodeHeight + flowRowGap;
        }
      }
    }
    return (rects, y - flowRowGap);
  }

  // Ports: each node spreads its outgoing edges over its bottom side and its
  // incoming edges over its top side. Lane edges take the left ports, loop
  // edges the right ones and the rest follow the other end, so that edges
  // leaving one node do not cross each other.
  List<(Offset, Offset)> ports(List<Rect> rects, List<FlowEdgeKind> kinds) {
    final outs = List.generate(n, (_) => <int>[]);
    final ins = List.generate(n, (_) => <int>[]);
    for (var e = 0; e < pairs.length; e++) {
      outs[pairs[e].$1].add(e);
      ins[pairs[e].$2].add(e);
    }
    double key(int e, int other) => switch (kinds[e]) {
      FlowEdgeKind.lane => double.negativeInfinity,
      FlowEdgeKind.back => double.infinity,
      FlowEdgeKind.forward => rects[other].center.dx,
    };
    void sortBy(List<int> list, int Function(int e) other) => list.sort((x, y) {
      final byKey = key(x, other(x)).compareTo(key(y, other(y)));
      return byKey != 0 ? byKey : x.compareTo(y);
    });
    Offset spread(Rect r, int k, int count, double y) =>
        Offset(r.left + r.width * (k + 1) / (count + 1), y);

    final starts = List.filled(pairs.length, Offset.zero);
    final ends = List.filled(pairs.length, Offset.zero);
    for (var v = 0; v < n; v++) {
      final o = outs[v];
      sortBy(o, (e) => pairs[e].$2);
      for (var k = 0; k < o.length; k++) {
        starts[o[k]] = spread(rects[v], k, o.length, rects[v].bottom);
      }
      final i = ins[v];
      sortBy(i, (e) => pairs[e].$1);
      for (var k = 0; k < i.length; k++) {
        ends[i[k]] = spread(rects[v], k, i.length, rects[v].top);
      }
    }
    return [for (var e = 0; e < pairs.length; e++) (starts[e], ends[e])];
  }

  // A forward edge needs a lane when its curve would cross another node.
  // Moving an edge to the lane moves the ports of the others, so check again
  // until nothing changes (edges only go from forward to lane: it ends).
  List<FlowEdgeKind> classify(List<Rect> rects) {
    final kinds = [
      for (final p in pairs)
        backEdges.contains(p) ? FlowEdgeKind.back : FlowEdgeKind.forward,
    ];
    var changed = true;
    while (changed) {
      changed = false;
      final ends = ports(rects, kinds);
      for (var e = 0; e < pairs.length; e++) {
        if (kinds[e] != FlowEdgeKind.forward) continue;
        final (a, b) = pairs[e];
        final (s, t) = ends[e];
        final obstacles = [
          for (var v = 0; v < n; v++)
            if (v != a &&
                v != b &&
                rects[v].bottom > s.dy &&
                rects[v].top < t.dy)
              rects[v].inflate(2),
        ];
        if (obstacles.isEmpty) continue;
        // About one sample every 8 px of height.
        final samples = math.max(24, ((t.dy - s.dy) / 8).ceil());
        for (var k = 1; k < samples; k++) {
          final p = _curvePoint(s, t, k / samples);
          if (obstacles.any((r) => r.contains(p))) {
            kinds[e] = FlowEdgeKind.lane;
            changed = true;
            break;
          }
        }
      }
    }
    return kinds;
  }

  var (rects, bottom) = place(0, w - rightGutter);
  var kinds = classify(rects);
  if (kinds.contains(FlowEdgeKind.lane)) {
    // Reserve the left lane and lay out again in the narrower band.
    (rects, bottom) = place(flowLaneGutter, w - rightGutter - flowLaneGutter);
    kinds = classify(rects);
  }
  final ends = ports(rects, kinds);

  // Lane slots: edges whose vertical spans overlap get different slots, so
  // that parallel lanes and their turns do not sit on top of each other.
  final slots = List.filled(pairs.length, 0);
  for (final side in [FlowEdgeKind.lane, FlowEdgeKind.back]) {
    final span = <int, (double, double)>{
      for (var e = 0; e < pairs.length; e++)
        if (kinds[e] == side)
          e: (
            math.min(ends[e].$1.dy, ends[e].$2.dy),
            math.max(ends[e].$1.dy, ends[e].$2.dy),
          ),
    };
    final order = span.keys.toList()
      ..sort((x, y) {
        final byTop = span[x]!.$1.compareTo(span[y]!.$1);
        return byTop != 0 ? byTop : x.compareTo(y);
      });
    final busyUntil = <double>[];
    for (final e in order) {
      final (from, to) = span[e]!;
      var slot = busyUntil.indexWhere((until) => until < from);
      if (slot == -1) {
        if (busyUntil.length < 3) {
          slot = busyUntil.length;
          busyUntil.add(to);
        } else {
          // Out of slots: share the one that frees up first.
          slot = 0;
          for (var k = 1; k < busyUntil.length; k++) {
            if (busyUntil[k] < busyUntil[slot]) slot = k;
          }
        }
      }
      busyUntil[slot] = math.max(busyUntil[slot], to);
      slots[e] = slot;
    }
  }

  List<Offset> route(int e) {
    final (start, end) = ends[e];
    if (kinds[e] == FlowEdgeKind.forward) return [start, end];
    final slot = slots[e];
    // Turn in the gap below the source and in the gap above the target.
    final y1 = start.dy + 12 + slot * 6;
    final y2 = end.dy - 12 - slot * 6;
    // The lane hugs the nodes it passes by (on a narrow screen, inside the
    // reserved gutter), so it does not wander to the edge of a wide screen.
    final beside = [
      for (final r in rects)
        if (r.bottom > math.min(y1, y2) && r.top < math.max(y1, y2)) r,
    ];
    final double x;
    if (kinds[e] == FlowEdgeKind.lane) {
      final edge = beside.fold(math.min(start.dx, end.dx), (m, r) {
        return math.min(m, r.left);
      });
      x = math.max(4 + slot * 5.0, edge - 14 + slot * 5);
    } else {
      final edge = beside.fold(math.max(start.dx, end.dx), (m, r) {
        return math.max(m, r.right);
      });
      x = math.min(w - 4 - slot * 5.0, edge + 14 - slot * 5);
    }
    return [
      start,
      Offset(start.dx, y1),
      Offset(x, y1),
      Offset(x, y2),
      Offset(end.dx, y2),
      end,
    ];
  }

  return FlowLayout(
    nodes: Map.unmodifiable({for (var i = 0; i < n; i++) names[i]: rects[i]}),
    edges: [
      for (var e = 0; e < pairs.length; e++)
        FlowEdgeLayout(
          from: names[pairs[e].$1],
          to: names[pairs[e].$2],
          kind: kinds[e],
          points: List.unmodifiable(route(e)),
        ),
    ],
    height: bottom + (hasBack ? flowLoopRoom : 0),
  );
}

/// Point at [t] on the S curve that joins [start] and [end] vertically.
Offset _curvePoint(Offset start, Offset end, double t) {
  final half = (end.dy - start.dy) / 2;
  final c1 = Offset(start.dx, start.dy + half);
  final c2 = Offset(end.dx, end.dy - half);
  final u = 1 - t;
  return start * (u * u * u) +
      c1 * (3 * u * u * t) +
      c2 * (3 * u * t * t) +
      end * (t * t * t);
}

/// Component `type: graph`: a workflow drawn as a vertical node map.
class FlowGraphView extends StatelessWidget {
  const FlowGraphView({
    super.key,
    required this.component,
    required this.state,
    required this.enabled,
    required this.onActions,
  });

  /// The component map as written in the spec (`nodes`, `edges`).
  final Map<String, dynamic> component;
  final Map<String, dynamic> state;

  /// False while a submit is running: nodes are not tappable then.
  final bool enabled;

  final Future<void> Function(List<ActionSpec> actions) onActions;

  @override
  Widget build(BuildContext context) {
    final nodes = _parseNodes();
    if (nodes.isEmpty) return const SizedBox.shrink();
    final edges = _parseEdges();
    final edgeByKey = <(String, String), _FlowEdgeData>{};
    for (final edge in edges) {
      edgeByKey.putIfAbsent((edge.from, edge.to), () => edge);
    }
    final pairs = [for (final e in edges) (e.from, e.to)];
    final ids = [for (final node in nodes) node.id];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final labelStyle = theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        Size measure(String text, TextStyle? style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final size = painter.size;
          painter.dispose();
          return size;
        }

        // Nodes grow with the system text size so that title and subtitle
        // fit (vertical padding 16, plus a little room).
        final nodeHeight = math.max(
          flowNodeHeight,
          (20 +
                  measure('Ag', theme.textTheme.titleSmall).height +
                  measure('Ag', theme.textTheme.bodySmall).height)
              .ceilToDouble(),
        );
        final layout = computeFlowLayout(
          ids,
          pairs,
          width,
          nodeHeight: nodeHeight,
        );

        final routes = [
          for (final edge in layout.edges)
            _route(
              edge,
              dashed: edgeByKey[(edge.from, edge.to)]?.dashed ?? false,
            ),
        ];
        final labels = _placeLabels(
          routes,
          layout,
          edgeByKey,
          width,
          (text) => measure(text, labelStyle),
        );
        // A label under the last row (a loop) may reach below the graph.
        final height = labels.fold(
          layout.height,
          (h, label) => math.max(h, label.rect.bottom),
        );

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FlowEdgePainter(
                    routes: routes,
                    normalColor: scheme.outline,
                    loopColor: scheme.tertiary,
                  ),
                ),
              ),
              for (final node in nodes)
                if (layout.nodes[node.id] case final rect?)
                  Positioned.fromRect(
                    rect: rect,
                    child: _nodeBox(context, node, rect.width),
                  ),
              for (final label in labels)
                Positioned.fromRect(
                  rect: label.rect,
                  child: IgnorePointer(
                    child: _pill(label.text, scheme, labelStyle),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Places the edge labels just below their output ports, on the outer side
  /// of the port (so the labels of one node move apart) and inside [width].
  /// Labels under one row that would overlap go to a second line.
  List<_PlacedLabel> _placeLabels(
    List<_EdgeRoute> routes,
    FlowLayout layout,
    Map<(String, String), _FlowEdgeData> edgeByKey,
    double width,
    Size Function(String text) measure,
  ) {
    final wanted = <_PlacedLabel>[];
    for (final route in routes) {
      final text = edgeByKey[(route.from, route.to)]?.label ?? '';
      final source = layout.nodes[route.from];
      if (text.isEmpty || source == null) continue;
      final size = measure(text);
      // Text plus the pill's padding, never wider than the graph.
      final w = math.min(size.width + 12, width);
      final port = route.start.dx;
      final left = port < source.center.dx - 0.5 ? port - 5 - w : port + 5;
      wanted.add(
        _PlacedLabel(
          text,
          Rect.fromLTWH(
            math.max(0, math.min(left, width - w)),
            route.start.dy + 3,
            w,
            size.height + 2,
          ),
        ),
      );
    }
    wanted.sort((a, b) {
      final byTop = a.rect.top.compareTo(b.rect.top);
      return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
    });

    final placed = <_PlacedLabel>[];
    double? rowTop;
    var ends = [double.negativeInfinity, double.negativeInfinity];
    for (final label in wanted) {
      if (label.rect.top != rowTop) {
        rowTop = label.rect.top;
        ends = [double.negativeInfinity, double.negativeInfinity];
      }
      var rect = label.rect;
      var line = ends.indexWhere((end) => rect.left >= end + 4);
      if (line == -1) {
        // Both lines are taken here: move right on the freer one.
        line = ends[0] <= ends[1] ? 0 : 1;
        final left = math.max(
          0.0,
          math.min(ends[line] + 4, width - rect.width),
        );
        rect = rect.shift(Offset(left - rect.left, 0));
      }
      rect = rect.shift(Offset(0, line * (rect.height + 2)));
      ends[line] = rect.right;
      placed.add(_PlacedLabel(label.text, rect));
    }
    return placed;
  }

  Widget _pill(String text, ColorScheme scheme, TextStyle? style) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Text(
            text,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

  String _text(Object? raw) => Template.render(asString(raw) ?? '', state);

  List<_FlowNodeData> _parseNodes() {
    final seen = <String>{};
    final result = <_FlowNodeData>[];
    for (final raw in asList(component['nodes'])) {
      final node = asMap(raw);
      final id = asString(node['id']);
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      result.add(
        _FlowNodeData(
          id: id,
          label: _text(node['label'] ?? id),
          subtitle: _text(node['subtitle']),
          badge: _text(node['badge']),
          tone: _text(node['tone']),
          icon: iconByName(asString(node['icon'])),
          actions: ActionSpec.ofComponent(node),
        ),
      );
    }
    return result;
  }

  List<_FlowEdgeData> _parseEdges() {
    final result = <_FlowEdgeData>[];
    for (final raw in asList(component['edges'])) {
      final edge = asMap(raw);
      final from = asString(edge['from']);
      final to = asString(edge['to']);
      if (from == null || to == null) continue;
      result.add(
        _FlowEdgeData(
          from: from,
          to: to,
          label: _text(edge['label']),
          dashed: asBool(edge['dashed']),
        ),
      );
    }
    return result;
  }

  Widget _nodeBox(BuildContext context, _FlowNodeData node, double width) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final dark = theme.brightness == Brightness.dark;
    final tappable = enabled && node.actions.isNotEmpty;
    // Same green and amber as `banner` and `metric`.
    final (borderColor, iconBackground, iconColor) = switch (node.tone) {
      'error' => (scheme.error, scheme.errorContainer, scheme.onErrorContainer),
      'success' =>
        dark
            ? (
                const Color(0xFF8CE0A4),
                const Color(0xFF14361F),
                const Color(0xFF8CE0A4),
              )
            : (
                const Color(0xFF1B7F3B),
                const Color(0xFFE6F4EA),
                const Color(0xFF14532D),
              ),
      'warning' =>
        dark
            ? (
                const Color(0xFFFFC857),
                const Color(0xFF3D2E05),
                const Color(0xFFF5D06F),
              )
            : (
                const Color(0xFFB26A00),
                const Color(0xFFFFF4D6),
                const Color(0xFF6B4A00),
              ),
      _ => (
        scheme.outlineVariant,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
    final radius = BorderRadius.circular(12);
    final label = [
      node.label,
      node.subtitle,
      node.badge,
    ].where((part) => part.isNotEmpty).join(', ');

    final box = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: tappable ? () => onActions(node.actions) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (node.icon != null) ...[
                  Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(node.icon, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.label,
                        style: textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (node.subtitle.isNotEmpty)
                        Text(
                          node.subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (node.badge.isNotEmpty)
                  Align(
                    alignment: Alignment.topRight,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width * 0.4),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          node.badge,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: label,
      button: tappable,
      onTap: tappable ? () => onActions(node.actions) : null,
      excludeSemantics: true,
      child: node.tone == 'muted' ? Opacity(opacity: 0.5, child: box) : box,
    );
  }
}

class _PlacedLabel {
  const _PlacedLabel(this.text, this.rect);

  final String text;
  final Rect rect;
}

class _FlowNodeData {
  const _FlowNodeData({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.badge,
    required this.tone,
    required this.icon,
    required this.actions,
  });

  final String id;
  final String label;
  final String subtitle;
  final String badge;
  final String tone;
  final IconData? icon;
  final List<ActionSpec> actions;
}

class _FlowEdgeData {
  const _FlowEdgeData({
    required this.from,
    required this.to,
    required this.label,
    required this.dashed,
  });

  final String from;
  final String to;
  final String label;
  final bool dashed;
}

/// Path and arrowhead of one edge, in graph coordinates.
class _EdgeRoute {
  const _EdgeRoute({
    required this.from,
    required this.to,
    required this.start,
    required this.path,
    required this.arrow,
    required this.back,
    required this.dashed,
  });

  final String from;
  final String to;

  /// Output port the edge leaves from.
  final Offset start;
  final Path path;

  /// Arrowhead triangle, or null when there is none.
  final Path? arrow;
  final bool back;
  final bool dashed;
}

_EdgeRoute _route(FlowEdgeLayout edge, {required bool dashed}) {
  final points = edge.points;
  final start = points.first;
  final end = points.last;
  final path = Path()..moveTo(start.dx, start.dy);
  Offset towardsEnd;
  if (points.length == 2) {
    // S curve with vertical tangents at both ports.
    final half = (end.dy - start.dy) / 2;
    path.cubicTo(
      start.dx,
      start.dy + half,
      end.dx,
      end.dy - half,
      end.dx,
      end.dy,
    );
    towardsEnd = Offset(0, half);
  } else {
    // Polyline with rounded corners.
    for (var i = 1; i < points.length - 1; i++) {
      final before = points[i] - points[i - 1];
      final after = points[i + 1] - points[i];
      final radius = math.min(
        8.0,
        math.min(before.distance, after.distance) / 2,
      );
      final entry = points[i] - _unit(before) * radius;
      final exit = points[i] + _unit(after) * radius;
      path
        ..lineTo(entry.dx, entry.dy)
        ..quadraticBezierTo(points[i].dx, points[i].dy, exit.dx, exit.dy);
    }
    path.lineTo(end.dx, end.dy);
    towardsEnd = end - points[points.length - 2];
  }
  return _EdgeRoute(
    from: edge.from,
    to: edge.to,
    start: start,
    path: path,
    arrow: _arrowHead(end, towardsEnd),
    back: edge.kind == FlowEdgeKind.back,
    dashed: dashed,
  );
}

Offset _unit(Offset v) {
  final length = v.distance;
  return length == 0 ? Offset.zero : v / length;
}

/// Filled triangle with its tip at [tip], pointing along [direction].
Path? _arrowHead(Offset tip, Offset direction) {
  final length = direction.distance;
  if (length == 0) return null;
  final unit = direction / length;
  final normal = Offset(-unit.dy, unit.dx);
  final base = tip - unit * 8;
  final left = base + normal * 4;
  final right = base - normal * 4;
  return Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(left.dx, left.dy)
    ..lineTo(right.dx, right.dy)
    ..close();
}

/// Replaces [source] by 6 px dashes with 4 px gaps.
Path _dashed(Path source) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    while (distance < metric.length) {
      final next = math.min(distance + (draw ? 6.0 : 4.0), metric.length);
      if (draw) out.addPath(metric.extractPath(distance, next), Offset.zero);
      distance = next;
      draw = !draw;
    }
  }
  return out;
}

class _FlowEdgePainter extends CustomPainter {
  const _FlowEdgePainter({
    required this.routes,
    required this.normalColor,
    required this.loopColor,
  });

  final List<_EdgeRoute> routes;
  final Color normalColor;
  final Color loopColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;
    for (final route in routes) {
      final color = route.back ? loopColor : normalColor;
      stroke.color = color;
      fill.color = color;
      canvas.drawPath(route.dashed ? _dashed(route.path) : route.path, stroke);
      final arrow = route.arrow;
      if (arrow != null && !route.dashed) canvas.drawPath(arrow, fill);
      // Output port, like the handles on n8n nodes.
      canvas.drawCircle(route.start, 3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowEdgePainter oldDelegate) => true;
}
