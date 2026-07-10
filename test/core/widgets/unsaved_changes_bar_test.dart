import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/widgets/unsaved_changes_bar.dart';

void main() {
  testWidgets('uses the light theme surface colors', (tester) async {
    final emphasisRevision = ValueNotifier(0);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF123456),
            surfaceContainerHighest: Color(0xFFF0F1F2),
          ),
        ),
        home: Scaffold(
          body: UnsavedChangesBar(
            emphasisRevision: emphasisRevision,
            message: 'Unsaved',
            discardLabel: 'Discard changes',
            compactDiscardLabel: 'Discard',
            saveLabel: 'Save',
            savingLabel: 'Saving',
            isSaving: false,
            onDiscard: () {},
            onSave: () {},
          ),
        ),
      ),
    );

    final materials = tester.widgetList<Material>(find.byType(Material));
    expect(
      materials.any((material) => material.color == const Color(0xFFF0F1F2)),
      isTrue,
    );
  });

  testWidgets('renders message and invokes both actions', (tester) async {
    var discarded = false;
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: UnsavedChangesBar(
                emphasisRevision: ValueNotifier(0),
                message: 'You have unsaved changes',
                discardLabel: 'Discard changes',
                compactDiscardLabel: 'Discard',
                saveLabel: 'Save',
                savingLabel: 'Saving',
                isSaving: false,
                onDiscard: () => discarded = true,
                onSave: () => saved = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('You have unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.tap(find.text('Save'));
    expect(discarded, isTrue);
    expect(saved, isTrue);
  });

  testWidgets('uses a compact stacked layout and shows saving progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: UnsavedChangesBar(
                emphasisRevision: ValueNotifier(0),
                message: 'You have unsaved changes',
                discardLabel: 'Discard changes',
                compactDiscardLabel: 'Discard',
                saveLabel: 'Save',
                savingLabel: 'Saving',
                isSaving: true,
                onDiscard: null,
                onSave: null,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Saving'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Discard'))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('controller emphasis animation completes', (tester) async {
    final emphasisRevision = ValueNotifier(0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnsavedChangesBar(
            emphasisRevision: emphasisRevision,
            message: 'Unsaved',
            discardLabel: 'Discard changes',
            compactDiscardLabel: 'Discard',
            saveLabel: 'Save',
            savingLabel: 'Saving',
            isSaving: false,
            onDiscard: () {},
            onSave: () {},
          ),
        ),
      ),
    );

    emphasisRevision.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
