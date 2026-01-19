import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:vagina/tools/builtin/call/end_call_tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';

/// Mock CallApi for testing
class MockCallApi implements CallApi {
  bool _endCallCalled = false;
  String? _lastEndContext;
  bool _shouldSucceed = true;

  bool get endCallCalled => _endCallCalled;
  String? get lastEndContext => _lastEndContext;

  void setShouldSucceed(bool succeed) {
    _shouldSucceed = succeed;
  }

  void reset() {
    _endCallCalled = false;
    _lastEndContext = null;
    _shouldSucceed = true;
  }

  @override
  Future<bool> endCall({String? endContext}) async {
    _endCallCalled = true;
    _lastEndContext = endContext;
    
    if (!_shouldSucceed) {
      throw Exception('Failed to end call');
    }
    
    return true;
  }
}

/// Mock ToolContext for testing
class MockToolContext implements ToolContext {
  @override
  final CallApi callApi;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  MockToolContext({required this.callApi});
}

void main() {
  group('Call Integration Tests', () {
    late MockCallApi mockCallApi;
    late EndCallTool endCallTool;
    late MockToolContext mockContext;

    setUp(() async {
      mockCallApi = MockCallApi();
      mockContext = MockToolContext(callApi: mockCallApi);
      endCallTool = EndCallTool();
      await endCallTool.init();
    });

    test('Voice call with end_call tool execution', () async {
      // Execute end_call tool without context
      final result = await endCallTool.execute({}, mockContext);

      // Parse and verify result
      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isTrue);
      expect(resultMap['ended'], isTrue);
      expect(mockCallApi.endCallCalled, isTrue);
      expect(mockCallApi.lastEndContext, isNull);
    });

    test('End call with context preservation', () async {
      // Execute end_call tool with context
      final result = await endCallTool.execute({
        'end_context': 'User requested to end call naturally'
      }, mockContext);

      // Verify result and context
      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isTrue);
      expect(mockCallApi.endCallCalled, isTrue);
      expect(
        mockCallApi.lastEndContext,
        equals('User requested to end call naturally'),
      );
    });

    test('End call during active async job', () async {
      // Simulate ending call while text agent job is running
      final result = await endCallTool.execute({
        'end_context': 'ultra_long job in progress'
      }, mockContext);

      // Verify call ended with appropriate context
      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isTrue);
      expect(mockCallApi.lastEndContext, equals('ultra_long job in progress'));
    });

    test('Error handling when end call fails', () async {
      // Setup mock to fail
      mockCallApi.setShouldSucceed(false);

      // Execute tool
      final result = await endCallTool.execute({}, mockContext);

      // Verify error is handled
      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isFalse);
      expect(resultMap['error'], contains('Error ending call'));
    });

    test('Multiple sequential calls to end_call', () async {
      // First call
      final result1 = await endCallTool.execute({}, mockContext);
      final resultMap1 = jsonDecode(result1) as Map<String, dynamic>;
      expect(resultMap1['success'], isTrue);

      // Reset mock and call again
      mockCallApi.reset();
      final result2 = await endCallTool.execute({}, mockContext);
      final resultMap2 = jsonDecode(result2) as Map<String, dynamic>;
      expect(resultMap2['success'], isTrue);
      expect(mockCallApi.endCallCalled, isTrue);
    });

    test('End call with various context types', () async {
      final contexts = [
        'natural conclusion',
        'user request',
        'ultra_long processing',
        'timeout',
        'error occurred',
      ];

      for (final ctx in contexts) {
        mockCallApi.reset();
        
        final result = await endCallTool.execute({
          'end_context': ctx
        }, mockContext);

        final resultMap = jsonDecode(result) as Map<String, dynamic>;
        expect(resultMap['success'], isTrue, reason: 'Failed for context: $ctx');
        expect(mockCallApi.lastEndContext, equals(ctx));
      }
    });

    test('End call with empty context string', () async {
      final result = await endCallTool.execute({
        'end_context': ''
      }, mockContext);

      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isTrue);
      expect(mockCallApi.lastEndContext, equals(''));
    });

    test('Tool definition contains correct metadata', () {
      final definition = endCallTool.definition;
      
      expect(definition.toolKey, equals('end_call'));
      expect(definition.categoryKey, equals('call'));
      expect(definition.displayName, equals('通話終了'));
      expect(definition.description, contains('End the current voice call'));
      
      // Verify parameters schema
      final schema = definition.parametersSchema;
      expect(schema['type'], equals('object'));
      expect(schema['properties'], isNotNull);
      expect(schema['properties']['end_context'], isNotNull);
    });
  });

  group('Call Tool Integration Scenarios', () {
    test('Scenario: Natural conversation ending', () async {
      // This documents the expected flow when conversation ends naturally
      final mockCallApi = MockCallApi();
      final mockContext = MockToolContext(callApi: mockCallApi);
      final tool = EndCallTool();
      await tool.init();

      final result = await tool.execute({
        'end_context': 'natural conclusion'
      }, mockContext);

      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isTrue);
      expect(mockCallApi.lastEndContext, contains('natural'));
    });

    test('Scenario: User explicitly requests to end', () async {
      final mockCallApi = MockCallApi();
      final mockContext = MockToolContext(callApi: mockCallApi);
      final tool = EndCallTool();
      await tool.init();

      final result = await tool.execute({
        'end_context': 'user request'
      }, mockContext);

      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isTrue);
      expect(mockCallApi.lastEndContext, equals('user request'));
    });

    test('Scenario: System initiates end after long task', () async {
      final mockCallApi = MockCallApi();
      final mockContext = MockToolContext(callApi: mockCallApi);
      final tool = EndCallTool();
      await tool.init();

      final result = await tool.execute({
        'end_context': 'ultra_long text agent task completed, call no longer needed'
      }, mockContext);

      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      expect(resultMap['success'], isTrue);
      expect(mockCallApi.endCallCalled, isTrue);
    });
  });
}
