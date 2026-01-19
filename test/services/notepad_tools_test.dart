import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/tools/builtin/notepad/notepad_list_tabs_tool.dart';
import 'package:vagina/tools/builtin/notepad/notepad_get_metadata_tool.dart';
import 'package:vagina/tools/builtin/notepad/notepad_get_content_tool.dart';
import 'package:vagina/tools/builtin/notepad/notepad_close_tab_tool.dart';

void main() {
  group('NotepadListTabsTool (runtime)', () {
    late NotepadService notepadService;
    late NotepadListTabsTool tool;

    setUp(() {
      notepadService = NotepadService();
      tool = NotepadListTabsTool();
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('returns empty list when no tabs exist', () async {
      final out = await tool.execute({});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      expect(result['tabs'], isEmpty);
      expect(result['count'], equals(0));
    });

    test('returns all tabs', () async {
      notepadService.createTab(content: 'Tab 1', mimeType: 'text/plain');
      notepadService.createTab(content: 'Tab 2', mimeType: 'text/markdown');

      final out = await tool.execute({});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      expect((result['tabs'] as List), hasLength(2));
      expect(result['count'], equals(2));
    });
  });

  group('NotepadGetMetadataTool (runtime)', () {
    late NotepadService notepadService;
    late NotepadGetMetadataTool tool;

    setUp(() {
      notepadService = NotepadService();
      tool = NotepadGetMetadataTool();
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('returns metadata for existing tab', () async {
      final tabId = notepadService.createTab(
        content: '# Hello',
        mimeType: 'text/markdown',
        title: 'Test',
      );

      final out = await tool.execute({'tabId': tabId});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      expect(result['metadata'], isNotNull);
      expect((result['metadata'] as Map)['id'], equals(tabId));
      expect((result['metadata'] as Map)['mimeType'], equals('text/markdown'));
    });

    test('returns error for non-existent tab', () async {
      final out = await tool.execute({'tabId': 'non_existent'});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });

  group('NotepadGetContentTool (runtime)', () {
    late NotepadService notepadService;
    late NotepadGetContentTool tool;

    setUp(() {
      notepadService = NotepadService();
      tool = NotepadGetContentTool();
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('returns content for existing tab', () async {
      final tabId = notepadService.createTab(
        content: 'Hello World',
        mimeType: 'text/plain',
      );

      final out = await tool.execute({'tabId': tabId});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      expect(result['content'], equals('Hello World'));
      expect(result['mimeType'], equals('text/plain'));
    });

    test('returns error for non-existent tab', () async {
      final out = await tool.execute({'tabId': 'non_existent'});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });

  group('NotepadCloseTabTool (runtime)', () {
    late NotepadService notepadService;
    late NotepadCloseTabTool tool;

    setUp(() {
      notepadService = NotepadService();
      tool = NotepadCloseTabTool();
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('closes existing tab', () async {
      final tabId = notepadService.createTab(
        content: 'Content',
        mimeType: 'text/plain',
      );

      final out = await tool.execute({'tabId': tabId});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      expect(notepadService.tabs, isEmpty);
    });

    test('returns error for non-existent tab', () async {
      final out = await tool.execute({'tabId': 'non_existent'});
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });
}
