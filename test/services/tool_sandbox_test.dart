import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/tools_runtime/sandbox_protocol.dart';
import 'package:vagina/services/tools_runtime/tool_sandbox_manager.dart';

import '../mocks/mock_repositories.mocks.dart';

void main() {
  group('ToolSandboxManager Lifecycle', () {
    test('spawns and disposes isolate', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandboxManager = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      // Initially not started
      expect(sandboxManager.isStarted, false);
      expect(sandboxManager.isDisposed, false);

      // Start the sandbox
      await sandboxManager.start();
      expect(sandboxManager.isStarted, true);

      // List tools to verify communication works
      final tools = await sandboxManager.getToolsFromWorker();
      expect(tools, isNotEmpty);
      expect(tools, isA<List<Map<String, dynamic>>>());

      // Dispose
      await sandboxManager.dispose();
      expect(sandboxManager.isDisposed, true);
      expect(sandboxManager.isStarted, false);

      // Can dispose multiple times
      await sandboxManager.dispose();
      expect(sandboxManager.isDisposed, true);
    });

    test('listSessionDefinitions throws if not started', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandboxManager = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      expect(
        () => sandboxManager.getToolsFromWorker(),
        throwsA(isA<StateError>()),
      );
    });

    test('listSessionDefinitions throws if disposed', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandboxManager = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      await sandboxManager.start();
      await sandboxManager.dispose();

      expect(
        () => sandboxManager.getToolsFromWorker(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Tool Execution - Document and Memory Operations', () {
    test('executes multiple tool operations in sequence', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandboxManager = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      // Setup mocks
      when(mockNotepadService.createTab(
        content: anyNamed('content'),
        mimeType: anyNamed('mimeType'),
        title: anyNamed('title'),
      )).thenReturn('artifact_1');

      when(mockMemoryRepository.save(any, any)).thenAnswer((_) async {});
      when(mockMemoryRepository.get('test_key')).thenAnswer(
        (_) async => 'test_value',
      );
      when(mockMemoryRepository.delete('test_key')).thenAnswer(
        (_) async => true,
      );

      addTearDown(() => sandboxManager.dispose());

      await sandboxManager.start();

      // Test 1: document_overwrite to create tab
      final result1 = await sandboxManager.execute('document_overwrite', {
        'content': '# Test Document',
        'mimeType': 'text/markdown',
        'title': 'My Document',
      });
      expect(result1, isNotNull);
      verify(mockNotepadService.createTab(
        content: '# Test Document',
        mimeType: 'text/markdown',
        title: 'My Document',
      )).called(1);

      // Test 2: memory_save
      final result2 = await sandboxManager.execute('memory_save', {
        'key': 'user_preference',
        'value': 'prefers English',
      });
      expect(result2, isNotNull);
      verify(mockMemoryRepository.save(
        'user_preference',
        'prefers English',
      )).called(1);

      // Test 3: memory_recall
      final result3 = await sandboxManager.execute('memory_recall', {
        'key': 'test_key',
      });
      expect(result3, isNotNull);
      verify(mockMemoryRepository.get('test_key')).called(1);

      // Test 4: memory_delete
      final result4 = await sandboxManager.execute('memory_delete', {
        'key': 'test_key',
      });
      expect(result4, isNotNull);
      verify(mockMemoryRepository.delete('test_key')).called(1);

      // Verify all results are JSON-serializable
      expect(() => jsonDecode(result1), returnsNormally);
      expect(() => jsonDecode(result2), returnsNormally);
      expect(() => jsonDecode(result3), returnsNormally);
      expect(() => jsonDecode(result4), returnsNormally);
    });

    test('execute throws StateError if not started', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandbox = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      expect(
        () => sandbox.execute('document_overwrite', {'content': 'test'}),
        throwsA(isA<StateError>()),
      );
    });

    test('execute throws StateError if disposed', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandbox = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      await sandbox.start();
      await sandbox.dispose();

      expect(
        () => sandbox.execute('document_overwrite', {'content': 'test'}),
        throwsA(isA<StateError>()),
      );
    });

    test('handles tool errors gracefully', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandbox = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      // Setup memory repository to throw
      when(mockMemoryRepository.save(any, any)).thenThrow(
        Exception('Database error'),
      );

      addTearDown(() => sandbox.dispose());

      await sandbox.start();

      expect(
        () => sandbox.execute('memory_save', {'key': 'test', 'value': 'data'}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Message Protocol - Sendability Validation', () {
    test('primitives are sendable', () {
      final (valid1, _) = isValueSendable(null);
      final (valid2, _) = isValueSendable(true);
      final (valid3, _) = isValueSendable(42);
      final (valid4, _) = isValueSendable(3.14);
      final (valid5, _) = isValueSendable('string');

      expect(valid1, true);
      expect(valid2, true);
      expect(valid3, true);
      expect(valid4, true);
      expect(valid5, true);
    });

    test('complex nested structures are sendable', () {
      final (valid, _) = isValueSendable({
        'tools': [
          {
            'key': 'tool1',
            'params': {
              'a': 1,
              'b': 2,
              'nested': {'deep': 'value'}
            },
          },
          {
            'key': 'tool2',
            'params': {'x': 'y'}
          },
        ],
        'metadata': {'count': 2, 'timestamp': '2026-01-18T11:54:39Z'},
      });
      expect(valid, true);
    });

    test('message envelope validation works', () {
      final validMessage = executeToolMessage(
        'test_tool',
        {'param': 'value'},
      );

      final (valid, error) = validateMessageEnvelope(validMessage);
      expect(valid, true);
      expect(error, isEmpty);
    });

    test('invalid envelope fails validation', () {
      final invalidMessage = {
        'type': 'execute',
        // Missing 'id' and 'payload'
      };

      final (valid, error) = validateMessageEnvelope(invalidMessage);
      expect(valid, false);
      expect(error, isNotEmpty);
    });
  });

  group('Push Events - toolsChanged Stream', () {
    test('toolsChanged stream is broadcast and operational', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandbox = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      addTearDown(() => sandbox.dispose());

      await sandbox.start();

      // Should be able to listen multiple times (broadcast stream)
      final events1 = <ToolsChangedEvent>[];
      final events2 = <ToolsChangedEvent>[];

      final sub1 = sandbox.toolsChanged.listen(events1.add);
      final sub2 = sandbox.toolsChanged.listen(events2.add);

      await Future.delayed(const Duration(milliseconds: 100));

      sub1.cancel();
      sub2.cancel();

      // Verify stream is broadcast-able
      expect(sandbox.toolsChanged, isA<Stream<ToolsChangedEvent>>());
    });
  });

  group('Integration Tests', () {
    test('document_overwrite creates tab with correct data', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandbox = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      when(mockNotepadService.createTab(
        content: anyNamed('content'),
        mimeType: anyNamed('mimeType'),
        title: anyNamed('title'),
      )).thenReturn('artifact_1');

      addTearDown(() => sandbox.dispose());

      await sandbox.start();

      final content = 'Test content with special chars: 中文 🎉';
      final result = await sandbox.execute('document_overwrite', {
        'content': content,
        'mimeType': 'text/plain',
      });

      expect(result, isNotNull);
      expect(() => jsonDecode(result), returnsNormally);

      // Verify mock was called with correct parameters
      verify(mockNotepadService.createTab(
        content: content,
        mimeType: 'text/plain',
      )).called(1);
    });

    test('memory round-trip preserves data through hostCall', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandbox = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      when(mockMemoryRepository.save(any, any)).thenAnswer((_) async {});
      when(mockMemoryRepository.get('stored_key')).thenAnswer(
        (_) async => 'stored_value_with_unicode_中文',
      );

      addTearDown(() => sandbox.dispose());

      await sandbox.start();

      // Save
      final saveResult = await sandbox.execute('memory_save', {
        'key': 'stored_key',
        'value': 'stored_value_with_unicode_中文',
      });
      expect(saveResult, isNotNull);

      // Recall
      final recallResult = await sandbox.execute('memory_recall', {
        'key': 'stored_key',
      });
      expect(recallResult, isNotNull);

      verify(mockMemoryRepository.save(
        'stored_key',
        'stored_value_with_unicode_中文',
      )).called(1);
      verify(mockMemoryRepository.get('stored_key')).called(1);
    });

    test('complete workflow with all tool types', () async {
      final mockNotepadService = MockNotepadService();
      final mockMemoryRepository = MockMemoryRepository();

      final sandbox = ToolSandboxManager(
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
      );

      when(mockNotepadService.createTab(
        content: anyNamed('content'),
        mimeType: anyNamed('mimeType'),
        title: anyNamed('title'),
      )).thenReturn('artifact_1');

      when(mockMemoryRepository.save(any, any)).thenAnswer((_) async {});
      when(mockMemoryRepository.get(any)).thenAnswer((_) async => 'data');

      await sandbox.start();
      expect(sandbox.isStarted, true);

      // List tools
      final tools = await sandbox.getToolsFromWorker();
      expect(tools, isNotEmpty);

      // Execute document operation
      final docResult = await sandbox.execute('document_overwrite', {
        'content': 'Document content',
        'mimeType': 'text/markdown',
      });
      expect(docResult, isNotNull);

      // Execute memory operation
      final memResult = await sandbox.execute('memory_save', {
        'key': 'key1',
        'value': 'value1',
      });
      expect(memResult, isNotNull);

      // Dispose
      await sandbox.dispose();
      expect(sandbox.isDisposed, true);

      // Verify can't use after dispose
      expect(
        () => sandbox.execute('memory_recall', {'key': 'test'}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
