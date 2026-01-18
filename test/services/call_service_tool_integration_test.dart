import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/realtime/realtime_api_client.dart';
import 'package:vagina/services/tool_service.dart';

import '../mocks/mock_repositories.mocks.dart';

void main() {
  group('CallService automatic tool execution flow - WebSocket Integration', () {
    late MockAudioRecorderService mockRecorder;
    late MockAudioPlayerService mockPlayer;
    late RealtimeApiClient apiClient;
    late MockWebSocketService mockWs;
    late MockConfigRepository mockConfig;
    late MockCallSessionRepository mockSessionRepository;
    late ToolService toolService;
    late MockMemoryRepository mockMemoryRepository;
    late NotepadService notepadService;
    late MockLogService mockLogService;
    late MockCallFeedbackService mockFeedback;

    late StreamController<Map<String, dynamic>> wsMessagesController;
    late CallService callService;

    setUp(() async {
      mockRecorder = MockAudioRecorderService();
      mockPlayer = MockAudioPlayerService();
      mockConfig = MockConfigRepository();
      mockSessionRepository = MockCallSessionRepository();
      mockMemoryRepository = MockMemoryRepository();
      mockLogService = MockLogService();
      mockFeedback = MockCallFeedbackService();
      mockWs = MockWebSocketService();

      notepadService = NotepadService(logService: mockLogService);

      // Initialize tool service with real tools
      toolService = ToolService(
        notepadService: notepadService,
        memoryRepository: mockMemoryRepository,
        configRepository: mockConfig,
      );
      toolService.initialize();

      // Create WebSocket messages stream
      wsMessagesController =
          StreamController<Map<String, dynamic>>.broadcast();

      // Setup mocks
      when(mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(mockRecorder.amplitudeStream).thenReturn(null);
      when(mockRecorder.startRecording())
          .thenAnswer((_) async => const Stream.empty());
      when(mockRecorder.stopRecording()).thenAnswer((_) async {});

      when(mockPlayer.addAudioData(any)).thenAnswer((_) async {});
      when(mockPlayer.markResponseComplete()).thenAnswer((_) async {});
      when(mockPlayer.stop()).thenAnswer((_) async {});

      when(mockConfig.hasAzureConfig()).thenAnswer((_) async => true);
      when(mockConfig.getRealtimeUrl())
          .thenAnswer((_) async => 'https://example.com/realtime');
      when(mockConfig.getApiKey())
          .thenAnswer((_) async => 'test-key');
      when(mockConfig.getEnabledTools()).thenAnswer((_) async => <String>[
        'get_current_time',
        'calculator',
        'memory_save',
        'memory_recall',
        'memory_delete',
        'document_read',
        'document_overwrite',
        'document_patch',
        'notepad_list_tabs',
        'notepad_get_metadata',
        'notepad_get_content',
        'notepad_close_tab',
      ]);

      when(mockSessionRepository.save(any)).thenAnswer((_) async {});

      when(mockMemoryRepository.save(any, any))
          .thenAnswer((_) async {});

      when(mockLogService.info(any, any)).thenAnswer((_) {});
      when(mockLogService.debug(any, any)).thenAnswer((_) {});
      when(mockLogService.warn(any, any)).thenAnswer((_) {});
      when(mockLogService.error(any, any)).thenAnswer((_) {});

      when(mockFeedback.playDialTone()).thenAnswer((_) async {});
      when(mockFeedback.stopDialTone()).thenAnswer((_) async {});
      when(mockFeedback.playCallEndTone()).thenAnswer((_) async {});
      when(mockFeedback.selectionClick()).thenAnswer((_) async {});
      when(mockFeedback.heavyImpact()).thenAnswer((_) async {});
      when(mockFeedback.dispose()).thenAnswer((_) async {});

      // Setup WebSocket mock
      when(mockWs.messages).thenAnswer((_) => wsMessagesController.stream);
      when(mockWs.isConnected).thenReturn(true);
      when(mockWs.connect(any)).thenAnswer((_) async {});
      when(mockWs.disconnect()).thenAnswer((_) async {});
      when(mockWs.dispose()).thenAnswer((_) async {});
      when(mockWs.send(any)).thenAnswer((_) {});

      // Create RealtimeApiClient with mocked WebSocket
      apiClient = RealtimeApiClient(
        webSocket: mockWs,
        logService: mockLogService,
      );

      // Create CallService
      callService = CallService(
        recorder: mockRecorder,
        player: mockPlayer,
        apiClient: apiClient,
        config: mockConfig,
        sessionRepository: mockSessionRepository,
        toolService: toolService,
        notepadService: notepadService,
        memoryRepository: mockMemoryRepository,
        logService: mockLogService,
        feedbackService: mockFeedback,
      );

      addTearDown(() async {
        await wsMessagesController.close();
        await callService.dispose();
      });
    });

    // =========================================================================
    // Helper Functions
    // =========================================================================

    /// Send a WebSocket message simulating function_call_arguments.delta
    void sendFunctionCallArgumentsDelta(String callId, String delta) {
      wsMessagesController.add({
        'type': 'response.function_call_arguments.delta',
        'call_id': callId,
        'delta': delta,
      });
    }

    /// Send a WebSocket message simulating function_call_arguments.done
    void sendFunctionCallArgumentsDone(String callId, String arguments) {
      wsMessagesController.add({
        'type': 'response.function_call_arguments.done',
        'call_id': callId,
        'arguments': arguments,
      });
    }

    /// Send a WebSocket message simulating output_item.added for function_call
    void sendFunctionCallOutputItemAdded(String callId, String name) {
      wsMessagesController.add({
        'type': 'response.output_item.added',
        'response_id': 'resp-1',
        'output_index': 0,
        'item': {
          'id': 'item-1',
          'object': 'realtime.item',
          'type': 'function_call',
          'call_id': callId,
          'name': name,
          'arguments': '',
        },
      });
    }

    /// Send complete function call via WebSocket messages
    void sendCompleteFunction(String callId, String name, String arguments) {
      sendFunctionCallOutputItemAdded(callId, name);
      sendFunctionCallArgumentsDelta(callId, arguments);
      sendFunctionCallArgumentsDone(callId, arguments);
    }

    // =========================================================================
    // Tests
    // =========================================================================

    test(
      'Calculator tool: function call is automatically executed and result sent via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();

        // Wait for startCall to fully complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Send function call via WebSocket messages
        final arguments = jsonEncode({'a': 10, 'b': 5, 'operation': 'add'});
        sendCompleteFunction('call-calc-1', 'calculator', arguments);

        // Wait for async processing
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify that the result was sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find the conversation.item.create message with function_call_output
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages, isNotEmpty,
            reason: 'Should send function_call_output via conversation.item.create');

        await callService.endCall();
      },
    );

    test(
      'Notepad tool (document_overwrite): automatically creates tab and sends result via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify initial state: no tabs
        expect(notepadService.tabs, isEmpty);

        // Send function call via WebSocket messages
        final arguments = jsonEncode({
          'content': '# Test Document\n\nThis is test content.',
          'mimeType': 'text/markdown',
        });
        sendCompleteFunction(
            'call-doc-overwrite-1', 'document_overwrite', arguments);

        // Wait for async processing
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify tab was created automatically
        expect(notepadService.tabs, isNotEmpty);
        expect(notepadService.tabs.length, 1);
        expect(notepadService.tabs.first.content,
            '# Test Document\n\nThis is test content.');

        // Verify that the result was sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find function_call_output message
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages, isNotEmpty);

        await callService.endCall();
      },
    );

    test(
      'Memory tool (memory_save): automatically saves and sends result via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send function call via WebSocket messages
        final arguments = jsonEncode({
          'key': 'user_preference',
          'value': 'prefers English language',
        });
        sendCompleteFunction('call-memory-save-1', 'memory_save', arguments);

        // Wait for async processing
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify repository.save was called automatically
        verify(mockMemoryRepository.save('user_preference', any)).called(1);

        // Verify that the result was sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find function_call_output message
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages, isNotEmpty);

        await callService.endCall();
      },
    );

    test(
      'Multiple sequential function calls are each executed and sent automatically via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Call 1: Calculator
        final args1 = jsonEncode({'a': 2, 'b': 3, 'operation': 'multiply'});
        sendCompleteFunction('call-seq-1', 'calculator', args1);
        await Future.delayed(const Duration(milliseconds: 150));

        // Call 2: Memory save
        final args2 = jsonEncode({
          'key': 'last_calc',
          'value': '2 * 3 = 6',
        });
        sendCompleteFunction('call-seq-2', 'memory_save', args2);
        await Future.delayed(const Duration(milliseconds: 150));

        // Verify both results were sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Count function_call_output messages
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages.length, greaterThanOrEqualTo(2),
            reason: 'Should have at least 2 function results sent');

        // Verify memory save was called
        verify(mockMemoryRepository.save('last_calc', any)).called(1);

        await callService.endCall();
      },
    );

    test(
      'Invalid JSON arguments error is automatically handled and sent via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send invalid function call arguments via WebSocket
        // The actual arguments will be invalid JSON when done
        wsMessagesController.add({
          'type': 'response.output_item.added',
          'response_id': 'resp-1',
          'output_index': 0,
          'item': {
            'id': 'item-1',
            'object': 'realtime.item',
            'type': 'function_call',
            'call_id': 'call-invalid-1',
            'name': 'calculator',
            'arguments': '',
          },
        });
        
        // Send invalid JSON in arguments
        wsMessagesController.add({
          'type': 'response.function_call_arguments.delta',
          'call_id': 'call-invalid-1',
          'delta': 'not valid json {]',
        });
        
        wsMessagesController.add({
          'type': 'response.function_call_arguments.done',
          'call_id': 'call-invalid-1',
          'arguments': 'not valid json {]',
        });

        // Wait for async processing
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify that the result was sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find function_call_output messages with errors
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages, isNotEmpty);

        await callService.endCall();
      },
    );

    test(
      'Unknown tool name error is automatically handled and sent via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Try to execute a tool that doesn't exist via WebSocket
        final arguments = jsonEncode({'param': 'value'});
        sendCompleteFunction('call-unknown-tool', 'nonexistent_tool', arguments);

        // Wait for async processing
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify that the result was sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find function_call_output messages
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages, isNotEmpty);

        await callService.endCall();
      },
    );

    test(
      'Empty JSON arguments error is automatically handled and sent via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Send function call with empty arguments via WebSocket
        wsMessagesController.add({
          'type': 'response.output_item.added',
          'response_id': 'resp-1',
          'output_index': 0,
          'item': {
            'id': 'item-1',
            'object': 'realtime.item',
            'type': 'function_call',
            'call_id': 'call-empty-args',
            'name': 'calculator',
            'arguments': '',
          },
        });
        
        // Send empty arguments
        wsMessagesController.add({
          'type': 'response.function_call_arguments.done',
          'call_id': 'call-empty-args',
          'arguments': '',
        });

        // Wait for async processing
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify that the result was sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find function_call_output messages
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages, isNotEmpty);

        await callService.endCall();
      },
    );

    test(
      'Tool execution errors are caught and sent as error results via WebSocket',
      () async {
        // Setup memory repository to throw error
        when(mockMemoryRepository.save(any, any)).thenThrow(
          Exception('Database connection failed'),
        );

        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Execute memory_save with error repo via WebSocket
        final arguments = jsonEncode({
          'key': 'test',
          'value': 'data',
        });
        sendCompleteFunction('call-memory-error', 'memory_save', arguments);

        // Wait for async processing
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify that the result was sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find function_call_output messages
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages, isNotEmpty);

        await callService.endCall();
      },
    );

    test(
      'Document_read tool: automatically reads and sends result via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // First, create a tab via document_overwrite
        final args1 = jsonEncode({
          'content': 'Initial content',
          'mimeType': 'text/plain',
        });
        sendCompleteFunction('call-create-doc', 'document_overwrite', args1);
        await Future.delayed(const Duration(milliseconds: 150));

        // Verify tab was created
        expect(notepadService.tabs, isNotEmpty);
        final tabId = notepadService.tabs.first.id;

        // Now read it back via WebSocket
        final args2 = jsonEncode({
          'tabId': tabId,
        });
        sendCompleteFunction('call-read-doc', 'document_read', args2);
        await Future.delayed(const Duration(milliseconds: 150));

        // Verify results were sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Find function_call_output messages
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages.length, greaterThanOrEqualTo(2),
            reason: 'Should have at least 2 function results sent');

        await callService.endCall();
      },
    );

    test(
      'Mixed tool calls (calculator and notepad) work together in automatic flow via WebSocket',
      () async {
        // Start CallService to set up subscriptions
        await callService.startCall();
        await Future.delayed(const Duration(milliseconds: 100));

        // Call 1: Calculator via WebSocket
        final calcArgs = jsonEncode({'a': 15, 'b': 3, 'operation': 'divide'});
        sendCompleteFunction('call-mixed-calc', 'calculator', calcArgs);
        await Future.delayed(const Duration(milliseconds: 150));

        // Call 2: Document creation via WebSocket
        final docArgs = jsonEncode({
          'content': 'Calculation result: 15 / 3 = 5',
          'mimeType': 'text/plain',
        });
        sendCompleteFunction('call-mixed-doc', 'document_overwrite', docArgs);
        await Future.delayed(const Duration(milliseconds: 150));

        // Call 3: Save memory via WebSocket
        final memArgs = jsonEncode({
          'key': 'calculation_result',
          'value': '5',
        });
        sendCompleteFunction('call-mixed-mem', 'memory_save', memArgs);
        await Future.delayed(const Duration(milliseconds: 150));

        // Verify all three were sent via WebSocket
        final sendCalls = verify(mockWs.send(captureAny)).captured;
        expect(sendCalls, isNotEmpty);

        // Count function_call_output messages
        final functionResultMessages = sendCalls.where((msg) =>
            msg is Map &&
            msg['type'] == 'conversation.item.create' &&
            msg['item']?['type'] == 'function_call_output');
        
        expect(functionResultMessages.length, greaterThanOrEqualTo(3),
            reason: 'Should have at least 3 function results sent');

        // Verify notepad has one tab
        expect(notepadService.tabs.length, 1);

        // Verify memory was saved
        verify(mockMemoryRepository.save('calculation_result', any)).called(1);

        await callService.endCall();
      },
    );
  });
}
