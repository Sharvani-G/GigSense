import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('GigShield navigation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GigShieldApp());

    // Verify that bottom navigation bar items are present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Log Job'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
  });
}
