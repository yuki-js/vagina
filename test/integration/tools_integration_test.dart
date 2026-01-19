import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:vagina/tools/builtin/call/end_call_tool.dart';
import 'package:vagina/tools/builtin/text_agent/list_available_agents_tool.dart';
import 'package:vagina/tools/builtin/text_agent/query_text_agent_tool.dart';
import 'package:vagina/tools/builtin/text_agent/get_text_agent_response_tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

/// Mock TextAgentApi for testing
class MockTextAgentApi implements TextAgentApi {
  final List<Map<String, dynamic>> _mockAgents = [
    {
      'id': 'agent_1',
      'name': 'Research Assistant',
      'description': 'Helps with research and analysis',
      'specialization': 'Research',
      'provider': 'azureOpenAI',
      'model_or_deployment': 'gpt-4o-mini',
    },
    {
      'id': 'agent_2',
      'name': 'Creative Writer',
      'description': 'Assists with creative writing',
      'specialization': 'Writing',
      'provider': 'azureOpenAI',
      'model_or_deployment': 'gpt-4o',
    },
  ];

  final Map<String, Map<String, dynamic>> _mockJobs = {};

  @override
  Future<Map<String, dynamic>> sendQuery(
    String agentId,
    String prompt,
    String expectLatency,
  ) async {
    // Validate agent exists
    if (!_mockAgents.any((agent) => agent['id'] == agentId)) {
      throw Exception('Agent not found: $agentId');
    }

    if (expectLatency == 'instant') {
      // Return instant response
      return {
        'mode': 'instant',
        'text': 'Mock response for: $prompt',
        'agentId': agentId,
      };
    } else {
      // Return async token
      final token = 'job_${DateTime.now().millisecondsSinceEpoch}';
      _mockJobs[token] = {
        'status': 'pending',
        'agentId': agentId,
        'prompt': prompt,
      };
      
      // Simulate async processing
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_mockJobs.containsKey(token)) {
          _mockJobs[token] = {
            'status': 'succeeded',
            'text': 'Async response for: $prompt',
          };
        }
      });
      
      return {
        'mode': 'async',
        'token': token,
        'agentId': agentId,
        'pollAfterMs': 1500,
      };
    }
  }

  @override
  Future<Map<String, dynamic>> getResult(String token) async {
    final job = _mockJobs[token];
    
    if (job == null) {
      throw Exception('Job not found: $token');
    }
    
    final status = job['status'] as String;
    
    if (status == 'pending' || status == 'running') {
      return {
        'status': status,
        'pollAfterMs': 1500,
      };
    } else if (status == 'succeeded') {
      return {
        'status': 'succeeded',
        'text': job['text'] as String,
      };
    } else {
      return {
        'status': 'failed',
        'error': job['error'] ?? 'Unknown error',
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return _mockAgents;
  }
}

/// Mock CallApi for testing
class MockCallApi implements CallApi {
  bool _endCallCalled = false;
  String? _lastEndContext;

  bool get endCallCalled => _endCallCalled;
  String? get lastEndContext => _lastEndContext;

  void reset() {
    _endCallCalled = false;
    _lastEndContext = null;
  }

  @override
  Future<bool> endCall({String? endContext}) async {
    _endCallCalled = true;
    _lastEndContext = endContext;
    return true;
  }
}

/// Mock ToolContext for testing
class MockToolContext implements ToolContext {
  @override
  final CallApi callApi;
  
  @override
  final TextAgentApi textAgentApi;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  MockToolContext({
    required this.callApi,
    required this.textAgentApi,
  });
}

void main() {
  group('Tools Integration Tests', () {
    late MockTextAgentApi mockTextAgentApi;
    late MockCallApi mockCallApi;
    late MockToolContext mockContext;

    setUp(() {
      mockTextAgentApi = MockTextAgentApi();
      mockCallApi = MockCallApi();
      mockContext = MockToolContext(
        callApi: mockCallApi,
        textAgentApi: mockTextAgentApi,
      );
    });

    test('Call list_available_agents → query_text_agent → get response', () async {
      // Step 1: List available agents
      final listTool = ListAvailableAgentsTool();
      await listTool.init(mockContext);
      
      final listResult = await listTool.execute({});
      final listData = jsonDecode(listResult) as Map<String, dynamic>;
      
      expect(listData['success'], isTrue);
      expect(listData['agents'], isA<List>());
      expect((listData['agents'] as List).length, equals(2));
      
      // Step 2: Select an agent and query it (instant)
      final agents = listData['agents'] as List;
      final firstAgent = agents[0] as Map<String, dynamic>;
      
      final queryTool = QueryTextAgentTool();
      await queryTool.init(mockContext);
      
      final queryResult = await queryTool.execute({
        'agent_id': firstAgent['id'],
        'prompt': 'What is machine learning?',
        'expect_latency': 'instant',
      });
      
      final queryData = jsonDecode(queryResult) as Map<String, dynamic>;
      
      expect(queryData['success'], isTrue);
      expect(queryData['mode'], equals('instant'));
      expect(queryData['text'], isNotEmpty);
      expect(queryData['text'], contains('Mock response'));
    });

    test('Query multiple agents simultaneously', () async {
      final queryTool = QueryTextAgentTool();
      await queryTool.init(mockContext);
      
      // Query agent 1
      final result1 = await queryTool.execute({
        'agent_id': 'agent_1',
        'prompt': 'Research question 1',
        'expect_latency': 'long',
      });
      
      final data1 = jsonDecode(result1) as Map<String, dynamic>;
      expect(data1['success'], isTrue);
      expect(data1['mode'], equals('async'));
      final token1 = data1['token'] as String;
      
      // Query agent 2
      final result2 = await queryTool.execute({
        'agent_id': 'agent_2',
        'prompt': 'Creative writing prompt',
        'expect_latency': 'long',
      });
      
      final data2 = jsonDecode(result2) as Map<String, dynamic>;
      expect(data2['success'], isTrue);
      expect(data2['mode'], equals('async'));
      final token2 = data2['token'] as String;
      
      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Get both results
      final getResponseTool = GetTextAgentResponseTool();
      await getResponseTool.init(mockContext);
      
      final response1 = await getResponseTool.execute({
        'token': token1,
      });
      
      final responseData1 = jsonDecode(response1) as Map<String, dynamic>;
      expect(responseData1['success'], isTrue);
      expect(responseData1['status'], equals('succeeded'));
      
      final response2 = await getResponseTool.execute({
        'token': token2,
      });
      
      final responseData2 = jsonDecode(response2) as Map<String, dynamic>;
      expect(responseData2['success'], isTrue);
      expect(responseData2['status'], equals('succeeded'));
    });

    test('Tool error handling and validation', () async {
      final queryTool = QueryTextAgentTool();
      await queryTool.init(mockContext);
      
      // Test missing agent_id
      final result1 = await queryTool.execute({
        'prompt': 'Test prompt',
        'expect_latency': 'instant',
      });
      
      final data1 = jsonDecode(result1) as Map<String, dynamic>;
      expect(data1['success'], isFalse);
      expect(data1['error'], contains('agent_id'));
      
      // Test missing prompt
      final result2 = await queryTool.execute({
        'agent_id': 'agent_1',
        'expect_latency': 'instant',
      });
      
      final data2 = jsonDecode(result2) as Map<String, dynamic>;
      expect(data2['success'], isFalse);
      expect(data2['error'], contains('prompt'));
      
      // Test invalid expect_latency
      final result3 = await queryTool.execute({
        'agent_id': 'agent_1',
        'prompt': 'Test',
        'expect_latency': 'invalid_value',
      });
      
      final data3 = jsonDecode(result3) as Map<String, dynamic>;
      expect(data3['success'], isFalse);
      expect(data3['error'], contains('expect_latency'));
    });

    test('Tool execution in sandbox isolation', () async {
      // This test verifies that tools can execute independently
      // and don't interfere with each other
      
      final listTool = ListAvailableAgentsTool();
      final queryTool = QueryTextAgentTool();
      final getResponseTool = GetTextAgentResponseTool();
      final endCallTool = EndCallTool();
      
      await Future.wait([
        listTool.init(mockContext),
        queryTool.init(mockContext),
        getResponseTool.init(mockContext),
        endCallTool.init(mockContext),
      ]);
      
      // Execute tools concurrently
      final results = await Future.wait([
        listTool.execute({}),
        queryTool.execute({
          'agent_id': 'agent_1',
          'prompt': 'Test',
          'expect_latency': 'instant',
        }),
        endCallTool.execute({'end_context': 'test'}),
      ]);
      
      // Verify all succeeded
      for (final result in results) {
        final data = jsonDecode(result) as Map<String, dynamic>;
        expect(data['success'], isTrue);
      }
    });

    test('Complete workflow: list → query async → poll → end call', () async {
      // Step 1: List agents
      final listTool = ListAvailableAgentsTool();
      await listTool.init(mockContext);
      final listResult = await listTool.execute({});
      final listData = jsonDecode(listResult) as Map<String, dynamic>;
      expect(listData['success'], isTrue);
      
      // Step 2: Query an agent with long latency
      final queryTool = QueryTextAgentTool();
      await queryTool.init(mockContext);
      final queryResult = await queryTool.execute({
        'agent_id': 'agent_1',
        'prompt': 'Complex analysis task',
        'expect_latency': 'ultra_long',
      });
      
      final queryData = jsonDecode(queryResult) as Map<String, dynamic>;
      expect(queryData['success'], isTrue);
      expect(queryData['mode'], equals('async'));
      final token = queryData['token'] as String;
      
      // Step 3: Poll for result
      await Future.delayed(const Duration(milliseconds: 150));
      
      final getResponseTool = GetTextAgentResponseTool();
      await getResponseTool.init(mockContext);
      final responseResult = await getResponseTool.execute({
        'token': token,
      });
      
      final responseData = jsonDecode(responseResult) as Map<String, dynamic>;
      expect(responseData['success'], isTrue);
      expect(responseData['status'], equals('succeeded'));
      
      // Step 4: End call after task completion
      final endCallTool = EndCallTool();
      await endCallTool.init(mockContext);
      final endResult = await endCallTool.execute({
        'end_context': 'ultra_long task completed',
      });
      
      final endData = jsonDecode(endResult) as Map<String, dynamic>;
      expect(endData['success'], isTrue);
      expect(mockCallApi.endCallCalled, isTrue);
      expect(mockCallApi.lastEndContext, contains('ultra_long'));
    });

    test('Error propagation through tool chain', () async {
      // Test querying non-existent agent
      final queryTool = QueryTextAgentTool();
      await queryTool.init(mockContext);
      
      final result = await queryTool.execute({
        'agent_id': 'non_existent_agent',
        'prompt': 'Test',
        'expect_latency': 'instant',
      });
      
      final data = jsonDecode(result) as Map<String, dynamic>;
      expect(data['success'], isFalse);
      expect(data['error'], contains('not found'));
    });

    test('Get result for non-existent token', () async {
      final getResponseTool = GetTextAgentResponseTool();
      await getResponseTool.init(mockContext);
      
      final result = await getResponseTool.execute({
        'token': 'invalid_token_123',
      });
      
      final data = jsonDecode(result) as Map<String, dynamic>;
      expect(data['success'], isFalse);
      expect(data['error'], isNotEmpty);
    });

    test('All tools have consistent response format', () async {
      final tools = [
        ListAvailableAgentsTool(),
        QueryTextAgentTool(),
        GetTextAgentResponseTool(),
        EndCallTool(),
      ];
      
      for (final tool in tools) {
        await tool.init(mockContext);
        
        // Verify definition structure
        final definition = tool.definition;
        expect(definition.toolKey, isNotEmpty);
        expect(definition.displayName, isNotEmpty);
        expect(definition.description, isNotEmpty);
        expect(definition.parametersSchema, isNotNull);
        expect(definition.parametersSchema['type'], equals('object'));
      }
    });
  });

  group('Real-world Tool Scenarios', () {
    late MockTextAgentApi mockTextAgentApi;
    late MockCallApi mockCallApi;
    late MockToolContext mockContext;

    setUp(() {
      mockTextAgentApi = MockTextAgentApi();
      mockCallApi = MockCallApi();
      mockContext = MockToolContext(
        callApi: mockCallApi,
        textAgentApi: mockTextAgentApi,
      );
    });

    test('Scenario: Voice call with quick fact-check', () async {
      // User asks during voice call: "What's the capital of France?"
      // Voice agent uses text agent for quick lookup
      
      final queryTool = QueryTextAgentTool();
      await queryTool.init(mockContext);
      
      final result = await queryTool.execute({
        'agent_id': 'agent_1',
        'prompt': 'What is the capital of France?',
        'expect_latency': 'instant',
      });
      
      final data = jsonDecode(result) as Map<String, dynamic>;
      expect(data['success'], isTrue);
      expect(data['mode'], equals('instant'));
      // Voice agent would then speak this response
    });

    test('Scenario: Complex research during call, end after submission', () async {
      // User asks for detailed analysis
      // Submit job and end call to continue in background
      
      final queryTool = QueryTextAgentTool();
      await queryTool.init(mockContext);
      
      final queryResult = await queryTool.execute({
        'agent_id': 'agent_1',
        'prompt': 'Write a comprehensive market analysis report',
        'expect_latency': 'ultra_long',
      });
      
      final queryData = jsonDecode(queryResult) as Map<String, dynamic>;
      expect(queryData['success'], isTrue);
      expect(queryData['token'], isNotEmpty);
      
      // Voice agent explains job was submitted and ends call
      final endCallTool = EndCallTool();
      await endCallTool.init(mockContext);
      
      final endResult = await endCallTool.execute({
        'end_context': 'ultra_long research job submitted',
      });
      
      final endData = jsonDecode(endResult) as Map<String, dynamic>;
      expect(endData['success'], isTrue);
    });

    test('Scenario: Check available agents before querying', () async {
      // Determine which agent is best for the task
      
      final listTool = ListAvailableAgentsTool();
      await listTool.init(mockContext);
      
      final listResult = await listTool.execute({});
      final listData = jsonDecode(listResult) as Map<String, dynamic>;
      
      final agents = listData['agents'] as List;
      
      // Find research agent
      final researchAgent = agents.firstWhere(
        (agent) => (agent as Map)['specialization'] == 'Research',
      ) as Map<String, dynamic>;
      
      expect(researchAgent['id'], equals('agent_1'));
      expect(researchAgent['name'], contains('Research'));
    });
  });
}
