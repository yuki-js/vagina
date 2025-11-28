import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/artifact_service.dart';

void main() {
  group('ArtifactService', () {
    late ArtifactService service;

    setUp(() {
      service = ArtifactService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initially has no tabs', () {
      expect(service.tabs, isEmpty);
      expect(service.selectedTabId, isNull);
    });

    test('createTab adds a new tab and selects it', () {
      final tabId = service.createTab(
        content: '# Hello World',
        mimeType: 'text/markdown',
      );

      expect(service.tabs, hasLength(1));
      expect(service.tabs.first.id, equals(tabId));
      expect(service.tabs.first.content, equals('# Hello World'));
      expect(service.tabs.first.mimeType, equals('text/markdown'));
      expect(service.selectedTabId, equals(tabId));
    });

    test('createTab generates title from markdown header', () {
      final tabId = service.createTab(
        content: '# My Document\n\nSome content here.',
        mimeType: 'text/markdown',
      );

      final tab = service.getTab(tabId);
      expect(tab?.title, equals('My Document'));
    });

    test('createTab allows custom title', () {
      final tabId = service.createTab(
        content: 'Some content',
        mimeType: 'text/plain',
        title: 'Custom Title',
      );

      final tab = service.getTab(tabId);
      expect(tab?.title, equals('Custom Title'));
    });

    test('updateTab updates content', () {
      final tabId = service.createTab(
        content: 'Initial content',
        mimeType: 'text/plain',
      );

      final success = service.updateTab(tabId, content: 'Updated content');

      expect(success, isTrue);
      expect(service.getTab(tabId)?.content, equals('Updated content'));
    });

    test('updateTab returns false for non-existent tab', () {
      final success = service.updateTab('non_existent', content: 'New content');
      expect(success, isFalse);
    });

    test('closeTab removes the tab', () {
      final tabId = service.createTab(
        content: 'Content',
        mimeType: 'text/plain',
      );

      final success = service.closeTab(tabId);

      expect(success, isTrue);
      expect(service.tabs, isEmpty);
      expect(service.selectedTabId, isNull);
    });

    test('closeTab returns false for non-existent tab', () {
      final success = service.closeTab('non_existent');
      expect(success, isFalse);
    });

    test('closeTab selects previous tab when closing selected tab', () {
      final tab1 = service.createTab(content: 'Tab 1', mimeType: 'text/plain');
      final tab2 = service.createTab(content: 'Tab 2', mimeType: 'text/plain');
      service.createTab(content: 'Tab 3', mimeType: 'text/plain');

      // Tab 3 is selected now
      service.closeTab(service.selectedTabId!);

      expect(service.selectedTabId, equals(tab2));

      // Close tab 2, should select tab 1
      service.closeTab(tab2);
      expect(service.selectedTabId, equals(tab1));
    });

    test('selectTab changes selection', () {
      final tab1 = service.createTab(content: 'Tab 1', mimeType: 'text/plain');
      service.createTab(content: 'Tab 2', mimeType: 'text/plain');

      service.selectTab(tab1);

      expect(service.selectedTabId, equals(tab1));
    });

    test('selectTab ignores non-existent tab', () {
      final tabId = service.createTab(content: 'Tab', mimeType: 'text/plain');
      
      service.selectTab('non_existent');

      expect(service.selectedTabId, equals(tabId));
    });

    test('getTabContent returns content by ID', () {
      final tabId = service.createTab(
        content: 'Test content',
        mimeType: 'text/plain',
      );

      expect(service.getTabContent(tabId), equals('Test content'));
      expect(service.getTabContent('non_existent'), isNull);
    });

    test('getTabMetadata returns metadata', () {
      final tabId = service.createTab(
        content: 'Test content',
        mimeType: 'text/markdown',
      );

      final metadata = service.getTabMetadata(tabId);

      expect(metadata, isNotNull);
      expect(metadata!['id'], equals(tabId));
      expect(metadata['mimeType'], equals('text/markdown'));
      expect(metadata['contentLength'], equals('Test content'.length));
    });

    test('listTabs returns metadata for all tabs', () {
      service.createTab(content: 'Tab 1', mimeType: 'text/plain');
      service.createTab(content: 'Tab 2', mimeType: 'text/markdown');

      final tabs = service.listTabs();

      expect(tabs, hasLength(2));
      expect(tabs[0]['mimeType'], equals('text/plain'));
      expect(tabs[1]['mimeType'], equals('text/markdown'));
    });

    test('clearTabs removes all tabs', () {
      service.createTab(content: 'Tab 1', mimeType: 'text/plain');
      service.createTab(content: 'Tab 2', mimeType: 'text/plain');

      service.clearTabs();

      expect(service.tabs, isEmpty);
      expect(service.selectedTabId, isNull);
    });
  });
}
