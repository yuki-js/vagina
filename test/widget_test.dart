// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: VaginaApp(),
      ),
    );

    // Verify that the app title is displayed
    // Note: On desktop platforms, "VAGINA" appears twice:
    // once in the custom title bar and once in the main content
    expect(find.text('VAGINA'), findsAtLeastNWidgets(1));
  });
}
