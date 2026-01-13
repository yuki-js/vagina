// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/main.dart';
import 'package:vagina/repositories/repository_factory.dart';

void main() {
  testWidgets('App smoke test - builds without crashing',
      (WidgetTester tester) async {
    // Initialize repository factory before building app
    await RepositoryFactory.initialize();
    
    // Build our app and trigger a frame.
    // This verifies the app can build and initialize without errors
    await tester.pumpWidget(
      const ProviderScope(
        child: VaginaApp(),
      ),
    );

    // Verify the app built successfully - there should be a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
