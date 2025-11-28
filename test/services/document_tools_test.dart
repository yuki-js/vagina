import 'package:flutter_test/flutter_test.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/tools/builtin/document_tools.dart';

void main() {
  group('DocumentOverwriteTool', () {
    late NotepadService notepadService;
    late DocumentOverwriteTool tool;

    setUp(() {
      notepadService = NotepadService();
      tool = DocumentOverwriteTool(notepadService: notepadService);
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('creates new tab when tabId not provided', () async {
      final result = await tool.execute({
        'content': '# New Document',
      });

      expect(result['success'], isTrue);
      expect(result['tabId'], isNotNull);
      expect(result['message'], equals('Document created successfully'));
      expect(notepadService.tabs, hasLength(1));
    });

    test('creates new tab with custom MIME type', () async {
      final result = await tool.execute({
        'content': 'Plain text content',
        'mime': 'text/plain',
      });

      expect(result['success'], isTrue);
      final tab = notepadService.getTab(result['tabId'] as String);
      expect(tab?.mimeType, equals('text/plain'));
    });

    test('creates new tab with custom title', () async {
      final result = await tool.execute({
        'content': 'Content',
        'title': 'My Custom Title',
      });

      expect(result['success'], isTrue);
      final tab = notepadService.getTab(result['tabId'] as String);
      expect(tab?.title, equals('My Custom Title'));
    });

    test('updates existing tab when tabId provided', () async {
      // First create a tab
      final createResult = await tool.execute({
        'content': 'Initial content',
      });
      final tabId = createResult['tabId'] as String;

      // Then update it
      final updateResult = await tool.execute({
        'tabId': tabId,
        'content': 'Updated content',
      });

      expect(updateResult['success'], isTrue);
      expect(updateResult['tabId'], equals(tabId));
      expect(updateResult['message'], equals('Document updated successfully'));
      expect(notepadService.getTabContent(tabId), equals('Updated content'));
    });

    test('returns error for non-existent tabId', () async {
      final result = await tool.execute({
        'tabId': 'non_existent',
        'content': 'Content',
      });

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });

  group('DocumentPatchTool', () {
    late NotepadService notepadService;
    late DocumentPatchTool tool;
    late DocumentOverwriteTool overwriteTool;

    setUp(() {
      notepadService = NotepadService();
      tool = DocumentPatchTool(notepadService: notepadService);
      overwriteTool = DocumentOverwriteTool(notepadService: notepadService);
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('applies patch to existing document', () async {
      // Create a document
      final createResult = await overwriteTool.execute({
        'content': 'Hello World',
      });
      final tabId = createResult['tabId'] as String;

      // Generate a proper unified diff patch using diff_match_patch
      final dmp = DiffMatchPatch();
      final patches = dmp.patch('Hello World', 'Hello Dart');
      final patchText = patchToText(patches);

      // Apply patch
      final patchResult = await tool.execute({
        'tabId': tabId,
        'patch': patchText,
      });

      expect(patchResult['success'], isTrue);
      expect(patchResult['appliedPatches'], equals(1));
      expect(notepadService.getTabContent(tabId), equals('Hello Dart'));
    });

    test('applies multiple patches', () async {
      final createResult = await overwriteTool.execute({
        'content': 'Hello World! Welcome to World!',
      });
      final tabId = createResult['tabId'] as String;

      // Generate patch
      final dmp = DiffMatchPatch();
      final patches = dmp.patch(
        'Hello World! Welcome to World!',
        'Hello Dart! Greetings to Dart!',
      );
      final patchText = patchToText(patches);

      final patchResult = await tool.execute({
        'tabId': tabId,
        'patch': patchText,
      });

      expect(patchResult['success'], isTrue);
      expect(notepadService.getTabContent(tabId), equals('Hello Dart! Greetings to Dart!'));
    });

    test('returns error for non-existent tab', () async {
      // Generate a simple patch
      final dmp = DiffMatchPatch();
      final patches = dmp.patch('text', 'other');
      final patchText = patchToText(patches);

      final result = await tool.execute({
        'tabId': 'non_existent',
        'patch': patchText,
      });

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });

    test('returns error for empty patch', () async {
      final createResult = await overwriteTool.execute({
        'content': 'Hello World',
      });
      final tabId = createResult['tabId'] as String;

      final patchResult = await tool.execute({
        'tabId': tabId,
        'patch': '',
      });

      expect(patchResult['success'], isFalse);
      expect(patchResult['error'], contains('No valid patches'));
    });
  });

  group('DocumentReadTool', () {
    late NotepadService notepadService;
    late DocumentReadTool tool;
    late DocumentOverwriteTool overwriteTool;

    setUp(() {
      notepadService = NotepadService();
      tool = DocumentReadTool(notepadService: notepadService);
      overwriteTool = DocumentOverwriteTool(notepadService: notepadService);
    });

    tearDown(() {
      notepadService.dispose();
    });

    test('reads document content', () async {
      final createResult = await overwriteTool.execute({
        'content': '# My Document\n\nContent here.',
        'mime': 'text/markdown',
        'title': 'Test Doc',
      });
      final tabId = createResult['tabId'] as String;

      final readResult = await tool.execute({'tabId': tabId});

      expect(readResult['success'], isTrue);
      expect(readResult['content'], equals('# My Document\n\nContent here.'));
      expect(readResult['mime'], equals('text/markdown'));
      expect(readResult['title'], equals('Test Doc'));
    });

    test('returns error for non-existent tab', () async {
      final result = await tool.execute({'tabId': 'non_existent'});

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });
}
