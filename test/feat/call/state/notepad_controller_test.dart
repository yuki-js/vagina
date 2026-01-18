import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/state/notepad_controller.dart';
import 'package:vagina/models/notepad_tab.dart';

void main() {
  group('NotepadState.copyWith', () {
    test('does not clear selectedTabId when only tabs change (regression)', () {
      final tab = NotepadTab(
        id: 't1',
        title: 'Tab 1',
        content: 'hello',
        mimeType: 'text/plain',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final state = NotepadState(tabs: [tab], selectedTabId: 't1');

      final updated = state.copyWith(
        tabs: [tab.copyWith(content: 'hello world')],
      );

      expect(updated.selectedTabId, equals('t1'));
    });

    test('can explicitly clear selectedTabId when requested', () {
      final tab = NotepadTab(
        id: 't1',
        title: 'Tab 1',
        content: 'hello',
        mimeType: 'text/plain',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final state = NotepadState(tabs: [tab], selectedTabId: 't1');

      final cleared = state.copyWith(selectedTabId: null);

      expect(cleared.selectedTabId, isNull);
    });
  });
}
