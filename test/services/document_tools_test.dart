import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/tools/builtin/builtin_tools.dart';
import '../mocks/mock_apis.dart';

void main() {
  group('DocumentOverwriteTool (runtime)', () {
    late NotepadService notepadService;
    late ToolContext ctx;
    late DocumentOverwriteTool tool;

    setUp(() {
      notepadService = NotepadService();
      ctx = ToolContext(
        notepadApi: TestNotepadApi(notepadService),
        memoryApi: TestMemoryApi(InMemoryRepository()),
      );
      tool = DocumentOverwriteTool();
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('creates new tab when tabId not provided', () async {
      final out = await tool.execute({'content': '# New Document'}, ctx);
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      expect(result['tabId'], isNotNull);
      expect(result['message'], equals('Document created successfully'));
      expect(notepadService.tabs, hasLength(1));
    });

    test('creates new tab with custom MIME type', () async {
      final out = await tool.execute(
        {
          'content': 'Plain text content',
          'mime': 'text/plain',
        },
        ctx,
      );
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      final tab = notepadService.getTab(result['tabId'] as String);
      expect(tab?.mimeType, equals('text/plain'));
    });

    test('creates new tab with custom title', () async {
      final out = await tool.execute(
        {
          'content': 'Content',
          'title': 'My Custom Title',
        },
        ctx,
      );
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isTrue);
      final tab = notepadService.getTab(result['tabId'] as String);
      expect(tab?.title, equals('My Custom Title'));
    });

    test('updates existing tab when tabId provided', () async {
      // First create a tab
      final createOut = await tool.execute({'content': 'Initial content'}, ctx);
      final createResult = jsonDecode(createOut) as Map<String, dynamic>;
      final tabId = createResult['tabId'] as String;

      // Then update it
      final updateOut = await tool.execute(
        {
          'tabId': tabId,
          'content': 'Updated content',
        },
        ctx,
      );
      final updateResult = jsonDecode(updateOut) as Map<String, dynamic>;

      expect(updateResult['success'], isTrue);
      expect(updateResult['tabId'], equals(tabId));
      expect(updateResult['message'], equals('Document updated successfully'));
      expect(notepadService.getTabContent(tabId), equals('Updated content'));
    });

    test('returns error for non-existent tabId', () async {
      final out = await tool.execute(
        {
          'tabId': 'non_existent',
          'content': 'Content',
        },
        ctx,
      );
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });

  group('DocumentPatchTool (runtime)', () {
    late NotepadService notepadService;
    late ToolContext ctx;
    late DocumentPatchTool tool;
    late DocumentOverwriteTool overwriteTool;

    setUp(() {
      notepadService = NotepadService();
      ctx = ToolContext(
        notepadApi: TestNotepadApi(notepadService),
        memoryApi: TestMemoryApi(InMemoryRepository()),
      );
      tool = DocumentPatchTool();
      overwriteTool = DocumentOverwriteTool();
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('applies patch to existing document', () async {
      // Create a document
      final createOut = await overwriteTool.execute({'content': 'Hello World'}, ctx);
      final createResult = jsonDecode(createOut) as Map<String, dynamic>;
      final tabId = createResult['tabId'] as String;

      // Generate a proper unified diff patch using diff_match_patch
      final dmp = DiffMatchPatch();
      final patches = dmp.patch('Hello World', 'Hello Dart');
      final patchText = patchToText(patches);

      // Apply patch
      final patchOut = await tool.execute(
        {
          'tabId': tabId,
          'patch': patchText,
        },
        ctx,
      );
      final patchResult = jsonDecode(patchOut) as Map<String, dynamic>;

      expect(patchResult['success'], isTrue);
      expect(patchResult['appliedPatches'], equals(1));
      expect(notepadService.getTabContent(tabId), equals('Hello Dart'));
    });

    test('applies multiple patches', () async {
      final createOut = await overwriteTool.execute(
        {'content': 'Hello World! Welcome to World!'},
        ctx,
      );
      final createResult = jsonDecode(createOut) as Map<String, dynamic>;
      final tabId = createResult['tabId'] as String;

      // Generate patch
      final dmp = DiffMatchPatch();
      final patches = dmp.patch(
        'Hello World! Welcome to World!',
        'Hello Dart! Greetings to Dart!',
      );
      final patchText = patchToText(patches);

      final patchOut = await tool.execute(
        {
          'tabId': tabId,
          'patch': patchText,
        },
        ctx,
      );
      final patchResult = jsonDecode(patchOut) as Map<String, dynamic>;

      expect(patchResult['success'], isTrue);
      expect(notepadService.getTabContent(tabId), equals('Hello Dart! Greetings to Dart!'));
    });

    test('returns error for non-existent tab', () async {
      // Generate a simple patch
      final dmp = DiffMatchPatch();
      final patches = dmp.patch('text', 'other');
      final patchText = patchToText(patches);

      final out = await tool.execute(
        {
          'tabId': 'non_existent',
          'patch': patchText,
        },
        ctx,
      );
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });

    test('returns error for empty patch', () async {
      final createOut = await overwriteTool.execute({'content': 'Hello World'}, ctx);
      final createResult = jsonDecode(createOut) as Map<String, dynamic>;
      final tabId = createResult['tabId'] as String;

      final patchOut = await tool.execute(
        {
          'tabId': tabId,
          'patch': '',
        },
        ctx,
      );
      final patchResult = jsonDecode(patchOut) as Map<String, dynamic>;

      expect(patchResult['success'], isFalse);
      expect(patchResult['error'], contains('No valid patches'));
    });
  });

  group('DocumentReadTool (runtime)', () {
    late NotepadService notepadService;
    late ToolContext ctx;
    late DocumentReadTool tool;
    late DocumentOverwriteTool overwriteTool;

    setUp(() {
      notepadService = NotepadService();
      ctx = ToolContext(
        notepadApi: TestNotepadApi(notepadService),
        memoryApi: TestMemoryApi(InMemoryRepository()),
      );
      tool = DocumentReadTool();
      overwriteTool = DocumentOverwriteTool();
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('reads document content', () async {
      final createOut = await overwriteTool.execute(
        {
          'content': '# My Document\n\nContent here.',
          'mime': 'text/markdown',
          'title': 'Test Doc',
        },
        ctx,
      );
      final createResult = jsonDecode(createOut) as Map<String, dynamic>;
      final tabId = createResult['tabId'] as String;

      final readOut = await tool.execute({'tabId': tabId}, ctx);
      final readResult = jsonDecode(readOut) as Map<String, dynamic>;

      expect(readResult['success'], isTrue);
      expect(readResult['content'], equals('# My Document\n\nContent here.'));
      expect(readResult['mime'], equals('text/markdown'));
      expect(readResult['title'], equals('Test Doc'));
    });

    test('returns error for non-existent tab', () async {
      final out = await tool.execute({'tabId': 'non_existent'}, ctx);
      final result = jsonDecode(out) as Map<String, dynamic>;

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });
}
