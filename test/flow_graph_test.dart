import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/apps/flow_graph.dart';
import 'package:n8n_connect/features/apps/spec_view.dart';

/// True when no two boxes in [rects] overlap.
bool _noOverlap(Iterable<Rect> rects) {
  final list = rects.toList();
  for (var i = 0; i < list.length; i++) {
    for (var j = i + 1; j < list.length; j++) {
      if (list[i].overlaps(list[j])) return false;
    }
  }
  return true;
}

/// Forward edges whose S curve passes through a node other than its ends.
List<FlowEdgeLayout> _crossings(FlowLayout layout) {
  final result = <FlowEdgeLayout>[];
  for (final edge in layout.edges) {
    if (edge.kind != FlowEdgeKind.forward) continue;
    final s = edge.start;
    final t = edge.end;
    final half = (t.dy - s.dy) / 2;
    final c1 = Offset(s.dx, s.dy + half);
    final c2 = Offset(t.dx, t.dy - half);
    for (var k = 1; k < 200; k++) {
      final x = k / 200;
      final u = 1 - x;
      final p =
          s * (u * u * u) +
          c1 * (3 * u * u * x) +
          c2 * (3 * u * x * x) +
          t * (x * x * x);
      final hit = layout.nodes.entries.any(
        (n) => n.key != edge.from && n.key != edge.to && n.value.contains(p),
      );
      if (hit) {
        result.add(edge);
        break;
      }
    }
  }
  return result;
}

void main() {
  group('computeFlowLayout', () {
    test('linear chain gets ranks 0, 1, 2 and increasing y', () {
      final layout = computeFlowLayout(
        ['A', 'B', 'C'],
        [('A', 'B'), ('B', 'C')],
        360,
      );

      final a = layout.nodes['A']!;
      final b = layout.nodes['B']!;
      final c = layout.nodes['C']!;
      expect(a.top, 0);
      expect(b.top, flowNodeHeight + flowRowGap);
      expect(c.top, 2 * (flowNodeHeight + flowRowGap));
      expect(a.top, lessThan(b.top));
      expect(b.top, lessThan(c.top));
      expect(layout.height, 3 * flowNodeHeight + 2 * flowRowGap);
      expect(layout.hasBackEdges, isFalse);
    });

    test('IF branch puts both targets side by side in one row', () {
      final layout = computeFlowLayout(
        ['A', 'B', 'C'],
        [('A', 'B'), ('A', 'C')],
        360,
      );

      final b = layout.nodes['B']!;
      final c = layout.nodes['C']!;
      expect(b.top, c.top);
      expect(b.top, greaterThan(layout.nodes['A']!.top));
      expect(b.overlaps(c), isFalse);
      expect(b.left, lessThan(c.left));
      expect(_noOverlap(layout.nodes.values), isTrue);
    });

    test('loop marks the closing edge as back and lays out every node', () {
      final layout = computeFlowLayout(
        ['A', 'B', 'C'],
        [('A', 'B'), ('B', 'C'), ('C', 'B')],
        360,
      );

      expect(layout.nodes.keys, containsAll(['A', 'B', 'C']));
      final back = layout.edges.where((e) => e.kind == FlowEdgeKind.back);
      expect(back.length, 1);
      expect(back.single.from, 'C');
      expect(back.single.to, 'B');
      expect(layout.hasBackEdges, isTrue);
      expect(layout.nodes['B']!.top, lessThan(layout.nodes['C']!.top));
      expect(
        layout.height,
        3 * flowNodeHeight + 2 * flowRowGap + 2 * flowLoopRoom,
      );
      // The loop runs up the right lane, clear of every node.
      final lane = back.single.points[2].dx;
      for (final rect in layout.nodes.values) {
        expect(rect.right, lessThan(lane));
      }
      expect(back.single.start.dy, layout.nodes['C']!.bottom);
      expect(back.single.end.dy, layout.nodes['B']!.top);
    });

    test('six nodes in one rank wrap into rows of two at width 360', () {
      final ids = ['N1', 'N2', 'N3', 'N4', 'N5', 'N6'];
      final layout = computeFlowLayout(ids, const [], 360);

      // floor((360 + 12) / (132 + 12)) = 2 columns.
      final rows = layout.nodes.values.map((r) => r.top).toSet();
      expect(rows.length, 3);
      for (final top in rows) {
        final inRow = layout.nodes.values.where((r) => r.top == top).length;
        expect(inRow, 2);
      }
      expect(_noOverlap(layout.nodes.values), isTrue);
      for (final rect in layout.nodes.values) {
        expect(rect.width, 174); // (360 - 12) / 2, below the 220 maximum
      }
    });

    test('six nodes in one rank fit one row at width 900', () {
      final ids = ['N1', 'N2', 'N3', 'N4', 'N5', 'N6'];
      final layout = computeFlowLayout(ids, const [], 900);

      // floor((900 + 12) / 144) = 6 columns: a single row.
      final rows = layout.nodes.values.map((r) => r.top).toSet();
      expect(rows.length, 1);
      expect(_noOverlap(layout.nodes.values), isTrue);
      for (final rect in layout.nodes.values) {
        expect(rect.width, 140); // (900 - 60) / 6, below the 220 maximum
      }
    });

    test('unknown edge ids are ignored and duplicate edges count once', () {
      final layout = computeFlowLayout(
        ['A', 'B'],
        [('A', 'B'), ('A', 'B'), ('A', 'X'), ('Y', 'B')],
        360,
      );

      expect(layout.edges.length, 1);
      expect(layout.edges.single.from, 'A');
      expect(layout.edges.single.to, 'B');
      expect(layout.nodes.keys, unorderedEquals(['A', 'B']));
    });

    test('nodes without edges go together in a last block', () {
      final layout = computeFlowLayout(['C', 'A', 'B', 'D'], [('A', 'B')], 360);

      expect(layout.nodes.keys, unorderedEquals(['A', 'B', 'C', 'D']));
      expect(layout.nodes['A']!.top, 0);
      final c = layout.nodes['C']!;
      expect(c.top, layout.nodes['B']!.bottom + flowGroupGap);
      expect(layout.nodes['D']!.top, c.top);
      expect(_noOverlap(layout.nodes.values), isTrue);
    });

    test('independent flows are stacked in their own blocks', () {
      final layout = computeFlowLayout(
        ['T1', 'T2', 'X', 'Y'],
        [('T1', 'X'), ('T2', 'Y')],
        360,
      );

      final x = layout.nodes['X']!;
      final t2 = layout.nodes['T2']!;
      expect(layout.nodes['T1']!.top, 0);
      expect(x.top, flowNodeHeight + flowRowGap);
      expect(t2.top, x.bottom + flowGroupGap);
      expect(layout.nodes['Y']!.top, t2.bottom + flowRowGap);
      expect(layout.height, layout.nodes['Y']!.bottom);
    });

    test('an edge that would cross a node takes the left lane', () {
      final layout = computeFlowLayout(
        ['A', 'B', 'C'],
        [('A', 'B'), ('B', 'C'), ('A', 'C')],
        360,
      );

      final skip = layout.edges.singleWhere(
        (e) => e.to == 'C' && e.from == 'A',
      );
      expect(skip.kind, FlowEdgeKind.lane);
      final a = layout.nodes['A']!;
      final c = layout.nodes['C']!;
      expect(skip.start.dy, a.bottom);
      expect(skip.end.dy, c.top);
      // The vertical part runs in the reserved gutter, left of every node.
      final lane = skip.points[2].dx;
      for (final rect in layout.nodes.values) {
        expect(rect.left, greaterThanOrEqualTo(flowLaneGutter));
        expect(lane, lessThan(rect.left));
      }
      // Lane edges take the left ports: the lane leaves A left of A -> B.
      final direct = layout.edges.firstWhere((e) => e.to == 'B');
      expect(skip.start.dx, lessThan(direct.start.dx));
      expect(direct.kind, FlowEdgeKind.forward);
    });

    test('outputs of one node get separate ports', () {
      final layout = computeFlowLayout(
        ['If', 'Yes', 'No'],
        [('If', 'Yes'), ('If', 'No')],
        360,
      );

      final yes = layout.edges.firstWhere((e) => e.to == 'Yes');
      final no = layout.edges.firstWhere((e) => e.to == 'No');
      expect(yes.start.dx, isNot(no.start.dx));
      expect(yes.kind, FlowEdgeKind.forward);
      expect(no.kind, FlowEdgeKind.forward);
      // Ordered like the targets, so the two curves do not cross.
      expect(
        yes.start.dx < no.start.dx,
        layout.nodes['Yes']!.left < layout.nodes['No']!.left,
      );
    });

    test('edges whose ports moved after the lanes are checked again', () {
      final layout = computeFlowLayout(
        ['A', 'B', 'C', 'D', 'E'],
        [('C', 'D'), ('A', 'E'), ('B', 'D'), ('B', 'E'), ('A', 'D')],
        360,
      );

      expect(_crossings(layout), isEmpty);
      expect(_noOverlap(layout.nodes.values), isTrue);
    });

    test('taller nodes keep the rows apart', () {
      final layout = computeFlowLayout(
        ['A', 'B'],
        [('A', 'B')],
        360,
        nodeHeight: 90,
      );

      expect(layout.nodes['A']!.height, 90);
      expect(layout.nodes['B']!.top, 90 + flowRowGap);
      expect(layout.height, 2 * 90 + flowRowGap);
    });

    test('empty input gives an empty layout', () {
      final layout = computeFlowLayout(const [], const [], 360);

      expect(layout.nodes, isEmpty);
      expect(layout.edges, isEmpty);
      expect(layout.height, 0);
    });
  });

  group('FlowGraph in SpecView', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    final component = <String, dynamic>{
      'type': 'graph',
      'nodes': [
        {
          'id': 'Webhook',
          'label': 'Webhook',
          'subtitle': 'webhook',
          'icon': 'bolt',
          'badge': '3 items',
          'action': {'type': 'toast', 'message': 'Tapped'},
        },
        {'id': 'Code', 'label': 'Code', 'subtitle': 'transform'},
        {
          'id': 'Failed',
          'label': 'Failed',
          'tone': 'error',
          'action': {'type': 'toast', 'message': 'Failed'},
        },
      ],
      'edges': [
        {'from': 'Webhook', 'to': 'Code', 'label': 'true'},
        {'from': 'Code', 'to': 'Failed', 'dashed': true},
      ],
    };

    testWidgets('renders node labels and calls onActions when tapped', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          SpecView(
            components: [component],
            state: const {},
            onChanged: (_, _) {},
            onActions: (a) async {
              tapped = true;
            },
          ),
        ),
      );

      expect(find.text('Webhook'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('transform'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);
      expect(find.text('true'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Webhook'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('node with tone error builds without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SpecView(
            components: [component],
            state: const {},
            onChanged: (_, _) {},
            onActions: (_) async {},
          ),
        ),
      );

      expect(find.text('Failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tappable node has a tap action for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var tapped = false;
      await tester.pumpWidget(
        host(
          SpecView(
            components: [component],
            state: const {},
            onChanged: (_, _) {},
            onActions: (_) async {
              tapped = true;
            },
          ),
        ),
      );

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Webhook')),
      );
      expect(
        node,
        containsSemantics(
          label: 'Webhook, webhook, 3 items',
          isButton: true,
          hasTapAction: true,
        ),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(tapped, isTrue);
      handle.dispose();
    });

    testWidgets('a graph inside a grid lays out', (tester) async {
      await tester.pumpWidget(
        host(
          SpecView(
            components: [
              {
                'type': 'grid',
                'columns': 2,
                'components': [
                  component,
                  {'type': 'text', 'text': 'Beside'},
                ],
              },
              {'type': 'text', 'text': 'Below'},
            ],
            state: const {},
            onChanged: (_, _) {},
            onActions: (_) async {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // The next component starts below the whole graph.
      expect(
        tester.getTopLeft(find.text('Below')).dy,
        greaterThan(tester.getBottomLeft(find.text('Failed')).dy),
      );
    });

    testWidgets('large system text fits in the nodes', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        host(
          SpecView(
            components: [component],
            state: const {},
            onChanged: (_, _) {},
            onActions: (_) async {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThan(flowNodeHeight),
      );
    });

    testWidgets('labels of several outputs of one node do not overlap', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SpecView(
            components: [
              {
                'type': 'graph',
                'nodes': [
                  {'id': 'Agent'},
                  {'id': 'Model'},
                  {'id': 'Memory'},
                  {'id': 'Tool'},
                ],
                'edges': [
                  {'from': 'Agent', 'to': 'Model', 'label': 'languageModel'},
                  {'from': 'Agent', 'to': 'Memory', 'label': 'memory'},
                  {'from': 'Agent', 'to': 'Tool', 'label': 'tool'},
                ],
              },
            ],
            state: const {},
            onChanged: (_, _) {},
            onActions: (_) async {},
          ),
        ),
      );

      final rects = [
        for (final text in ['languageModel', 'memory', 'tool'])
          tester.getRect(find.text(text)),
      ];
      expect(_noOverlap(rects), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nodes are not tappable while disabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          SpecView(
            components: [component],
            state: const {},
            enabled: false,
            onChanged: (_, _) {},
            onActions: (_) async {
              tapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Webhook'));
      await tester.pump();

      expect(tapped, isFalse);
    });
  });
}
