import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/artifact_service.dart';
import 'package:vagina/services/tools/builtin/artifact_tools.dart';

void main() {
  group('ArtifactListTabsTool', () {
    late ArtifactService artifactService;
    late ArtifactListTabsTool tool;

    setUp(() {
      artifactService = ArtifactService();
      tool = ArtifactListTabsTool(artifactService: artifactService);
    });

    tearDown(() {
      artifactService.dispose();
    });

    test('returns empty list when no tabs exist', () async {
      final result = await tool.execute({});

      expect(result['success'], isTrue);
      expect(result['tabs'], isEmpty);
      expect(result['count'], equals(0));
    });

    test('returns all tabs', () async {
      artifactService.createTab(content: 'Tab 1', mimeType: 'text/plain');
      artifactService.createTab(content: 'Tab 2', mimeType: 'text/markdown');

      final result = await tool.execute({});

      expect(result['success'], isTrue);
      expect((result['tabs'] as List), hasLength(2));
      expect(result['count'], equals(2));
    });
  });

  group('ArtifactGetMetadataTool', () {
    late ArtifactService artifactService;
    late ArtifactGetMetadataTool tool;

    setUp(() {
      artifactService = ArtifactService();
      tool = ArtifactGetMetadataTool(artifactService: artifactService);
    });

    tearDown(() {
      artifactService.dispose();
    });

    test('returns metadata for existing tab', () async {
      final tabId = artifactService.createTab(
        content: '# Hello',
        mimeType: 'text/markdown',
        title: 'Test',
      );

      final result = await tool.execute({'tabId': tabId});

      expect(result['success'], isTrue);
      expect(result['metadata'], isNotNull);
      expect((result['metadata'] as Map)['id'], equals(tabId));
      expect((result['metadata'] as Map)['mimeType'], equals('text/markdown'));
    });

    test('returns error for non-existent tab', () async {
      final result = await tool.execute({'tabId': 'non_existent'});

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });

  group('ArtifactGetContentTool', () {
    late ArtifactService artifactService;
    late ArtifactGetContentTool tool;

    setUp(() {
      artifactService = ArtifactService();
      tool = ArtifactGetContentTool(artifactService: artifactService);
    });

    tearDown(() {
      artifactService.dispose();
    });

    test('returns content for existing tab', () async {
      final tabId = artifactService.createTab(
        content: 'Hello World',
        mimeType: 'text/plain',
      );

      final result = await tool.execute({'tabId': tabId});

      expect(result['success'], isTrue);
      expect(result['content'], equals('Hello World'));
      expect(result['mimeType'], equals('text/plain'));
    });

    test('returns error for non-existent tab', () async {
      final result = await tool.execute({'tabId': 'non_existent'});

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });

  group('ArtifactCloseTabTool', () {
    late ArtifactService artifactService;
    late ArtifactCloseTabTool tool;

    setUp(() {
      artifactService = ArtifactService();
      tool = ArtifactCloseTabTool(artifactService: artifactService);
    });

    tearDown(() {
      artifactService.dispose();
    });

    test('closes existing tab', () async {
      final tabId = artifactService.createTab(
        content: 'Content',
        mimeType: 'text/plain',
      );

      final result = await tool.execute({'tabId': tabId});

      expect(result['success'], isTrue);
      expect(artifactService.tabs, isEmpty);
    });

    test('returns error for non-existent tab', () async {
      final result = await tool.execute({'tabId': 'non_existent'});

      expect(result['success'], isFalse);
      expect(result['error'], contains('Tab not found'));
    });
  });
}
