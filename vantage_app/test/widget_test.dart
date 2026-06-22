import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantage_app/ui/landing_screen.dart';

void main() {
  testWidgets('App landing screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));

    // Verify that our landing screen is rendered with key elements
    expect(find.text('Vantage'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
