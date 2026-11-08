import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:n8n_connect/features/startup/brand.dart';

void main() {
  testWidgets(
    'BrandMark draws the logo with CustomPaint at the requested size',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: BrandMark(size: 72))),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(BrandMark),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(BrandMark)), const Size(72, 72));
    },
  );
}
