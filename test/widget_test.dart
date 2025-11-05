// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mcp/index_page.dart';

void main() {
  testWidgets('IndexPage renders title and action button', (WidgetTester tester) async {
    // Build a minimal app that shows IndexPage to isolate the test from routing.
    await tester.pumpWidget(const MaterialApp(home: IndexPage()));
    // Allow any pending frames (layout) to complete.
    await tester.pumpAndSettle();

    // Verify that an IndexPage widget is present.
    final indexFinder = find.byType(IndexPage);
    if (indexFinder.evaluate().isEmpty) {
      // helpful debug output for failing CI/local runs
      debugDumpApp();
    }
    expect(indexFinder, findsOneWidget);

    // Collect all visible Text widget strings to search substrings directly.
    final texts = find.byType(Text).evaluate().map((e) {
      final w = e.widget as Text;
      return w.data ?? w.textSpan?.toPlainText();
    }).whereType<String>().toList();
    // ignore: avoid_print
    print('Visible texts: $texts');

    // Assert that at least one visible text contains our title substring.
    expect(texts.any((t) => t.contains('ಮಾತೃತ್ವ')), isTrue,
        reason: 'Expected to find a visible Text containing "ಮಾತೃತ್ವ".');

    // Check ElevatedButtons for a label containing 'ಮಾಹಿತಿ'.
    final buttonChildren = find.byType(ElevatedButton).evaluate().map((e) => (e.widget as ElevatedButton).child).toList();
    // Map child widgets to their text content (if any).
    final buttonLabels = buttonChildren.map((child) {
      if (child is Text) return child.data ?? '';
      if (child is Row) {
        return child.children.whereType<Text>().map((t) => t.data ?? '').join(' ');
      }
      return '';
    }).toList();
    // ignore: avoid_print
    print('ElevatedButton labels: $buttonLabels');
    expect(buttonLabels.any((t) => t.contains('ಮಾಹಿತಿ')), isTrue,
        reason: 'Expected to find an ElevatedButton label containing "ಮಾಹಿತಿ".');
  });
}
