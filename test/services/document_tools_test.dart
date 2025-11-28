import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/artifact_service.dart';
import 'package:vagina/services/tools/builtin/document_tools.dart';

void main() {
  group('DocumentOverwriteTool', () {
    late ArtifactService artifactService;
    late DocumentOverwriteTool tool;

    setUp(() {
      artifactService = ArtifactService();
      tool = DocumentOverwriteTool(artifactService: artifactService);
    });

    tearDown(() {
      artifactService.dispose();
    });

    test('creates new tab when tabId not provided', () async {
      final result = await tool.execute({
        'content': '# New Document',
      });

      expect(result['success'], isTrue);
      expect(result['tabId'], isNotNull);
      expect(result['message'], equals('Document created successfully'));
      expect(artifactService.tabs, hasLength(1));
    });

    test('creates new tab with custom MIME type', () async {
      final result = await tool.execute({
        'content': 'Plain text content',
        'mime': 'text/plain',
      });

      expect(result['success'], isTrue);
      final tab = artifactService.getTab(result['tabId'] as String);
      expect(tab?.mimeType, equals('text/plain'));
    });

    test('creates new tab with custom title', () async {
      final result = await tool.execute({
        'content': 'Content',
        'title': 'My Custom Title',
      });

      expect(result['success'], isTrue);
      final tab = artifactService.getTab(result['tabId'] as String);
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
      expect(artifactService.getTabContent(tabId), equals('Updated content'));
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
    late ArtifactService artifactService;
    late DocumentPatchTool tool;
    late DocumentOverwriteTool overwriteTool;

    setUp(() {
      artifactService = ArtifactService();
      tool = DocumentPatchTool(artifactService: artifactService);
      overwriteTool = DocumentOverwriteTool(artifactService: artifactService);
    });

    tearDown(() {
      artifactService.dispose();
    });

    test('applies patch to existing document', () async {
      // Create a document
      final createResult = await overwriteTool.execute({
        'content': 'Hello World',
      });
      final tabId = createResult['tabId'] as String;

      // Apply patch in unified diff format
      final patchResult = await tool.execute({
        'tabId': tabId,
        'patch': '@@ -1,11 +1,10 @@\n Hello \n-World\n+Dart\n',
      });

      expect(patchResult['success'], isTrue);
      expect(patchResult['appliedPatches'], equals(1));
      expect(artifactService.getTabContent(tabId), equals('Hello Dart'));
    });

    test('applies multiple patches', () async {
      final createResult = await overwriteTool.execute({
        'content': 'Hello World! Welcome to World!',
      });
      final tabId = createResult['tabId'] as String;

      // Apply patches in unified diff format  
      final patchResult = await tool.execute({
        'tabId': tabId,
        'patch': '@@ -1,30 +1,28 @@\n Hello \n-World\n+Dart\n ! \n-Welcome\n+Greetings\n  to World!\n',
      });

      expect(patchResult['success'], isTrue);
      expect(artifactService.getTabContent(tabId), contains('Dart'));
    });

    test('returns error when patch text not found', () async {
      final createResult = await overwriteTool.execute({
        'content': 'Hello World',
      });
      final tabId = createResult['tabId'] as String;

      final patchResult = await tool.execute({
        'tabId': tabId,
        'patch': '@@ -1,20 +1,20 @@\n Something\n-Nonexistent\n+Different\n text\n',
      });

      // Patch should fail because the context doesn't match
      expect(patchResult['success'], isFalse);
    });

    test('returns error for non-existent tab', () async {
      final result = await tool.execute({
        'tabId': 'non_existent',
        'patch': '@@ -1,5 +1,5 @@\n-text\n+other\n',
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
    late ArtifactService artifactService;
    late DocumentReadTool tool;
    late DocumentOverwriteTool overwriteTool;

    setUp(() {
      artifactService = ArtifactService();
      tool = DocumentReadTool(artifactService: artifactService);
      overwriteTool = DocumentOverwriteTool(artifactService: artifactService);
    });

    tearDown(() {
      artifactService.dispose();
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
