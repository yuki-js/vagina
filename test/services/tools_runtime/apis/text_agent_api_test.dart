import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

// Generate mocks: dart run build_runner build
@GenerateMocks([http.Client])
import 'text_agent_api_test.mocks.dart';

void main() {
  group('TextAgentApiClient - Tool Filtering', () {
    late MockClient mockHttpClient;
    late TextAgentApiClient client;

    setUp(() {
      mockHttpClient = MockClient();
      client = TextAgentApiClient(
        httpClient: mockHttpClient,
        initialData: [
          {
            'id': 'agent-1',
            'name': 'Test Agent 1',
            'description': 'Test agent 1',
            'provider': 'openai',
            'apiKey': 'test-key-1',
            'apiIdentifier': 'gpt-4o',
          },
          {
            'id': 'agent-2',
            'name': 'Test Agent 2',
            'description': 'Test agent 2',
            'provider': 'openai',
            'apiKey': 'test-key-2',
            'apiIdentifier': 'gpt-4o',
          },
        ],
        executeToolCallback: (toolKey, args) async {
          // Dummy tool execution callback for testing
          return jsonEncode({'success': true, 'tool': toolKey});
        },
        availableTools: [
          {
            'type': 'function',
            'function': {
              'name': 'tool1',
              'description': 'Tool 1',
              'parameters': {},
            },
          },
          {
            'type': 'function',
            'function': {
              'name': 'tool2',
              'description': 'Tool 2',
              'parameters': {},
            },
          },
          {
            'type': 'function',
            'function': {
              'name': 'tool3',
              'description': 'Tool 3',
              'parameters': {},
            },
          },
        ],
      );
    });

    tearDown(() {
      client.dispose();
    });

    test('updateAgentTools() should register agent tool configuration', () {
      // Arrange
      final toolConfig = {
        'tool1': true,
        'tool2': false,
        'tool3': true,
      };

      // Act
      client.updateAgentTools('agent-1', toolConfig);

      // Assert - no exception means success
      expect(true, true);
    });

    test('sendQuery with no tool config should send all available tools',
        () async {
      // Arrange
      final mockResponse = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
            },
          ],
        }),
        200,
      );

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      // Act
      final result = await client.sendQuery(
        'agent-1',
        'Test prompt',
      );

      // Assert
      expect(result, 'Test response');

      // Verify that all tools were sent
      final captured = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final bodyStr = captured[2] as String;
      final requestBody = jsonDecode(bodyStr) as Map<String, dynamic>;
      expect(requestBody['tools'], isA<List>());
      final tools = requestBody['tools'] as List;
      expect(tools.length, 3); // All 3 tools
    });

    test('sendQuery with tool config should send only enabled tools', () async {
      // Arrange
      final toolConfig = {
        'tool1': true,
        'tool2': false, // Disabled
        'tool3': true,
      };
      client.updateAgentTools('agent-1', toolConfig);

      final mockResponse = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
            },
          ],
        }),
        200,
      );

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      // Act
      final result = await client.sendQuery(
        'agent-1',
        'Test prompt',
      );

      // Assert
      expect(result, 'Test response');

      // Verify that only enabled tools were sent
      final captured = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final bodyStr = captured[2] as String;
      final requestBody = jsonDecode(bodyStr) as Map<String, dynamic>;
      expect(requestBody['tools'], isA<List>());
      final tools = requestBody['tools'] as List;
      expect(tools.length, 2); // Only 2 enabled tools

      final toolNames = tools.map((t) => t['function']['name']).toList();
      expect(toolNames, contains('tool1'));
      expect(toolNames, contains('tool3'));
      expect(toolNames, isNot(contains('tool2'))); // tool2 is disabled
    });

    test(
        'sendQuery with empty tool config should send all tools (key not in map = true)',
        () async {
      // Arrange
      client.updateAgentTools('agent-1', {}); // Empty config

      final mockResponse = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
            },
          ],
        }),
        200,
      );

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      // Act
      final result = await client.sendQuery(
        'agent-1',
        'Test prompt',
      );

      // Assert
      expect(result, 'Test response');

      // Verify that all tools were sent (empty config = all tools enabled)
      final captured = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final bodyStr = captured[2] as String;
      final requestBody = jsonDecode(bodyStr) as Map<String, dynamic>;
      expect(requestBody['tools'], isA<List>());
      final tools = requestBody['tools'] as List;
      expect(tools.length, 3); // All 3 tools
    });

    test('tool key not in config map should default to enabled (true)',
        () async {
      // Arrange
      final toolConfig = {
        'tool1': false, // Only tool1 explicitly disabled
        // tool2 and tool3 not in map, should default to true
      };
      client.updateAgentTools('agent-1', toolConfig);

      final mockResponse = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
            },
          ],
        }),
        200,
      );

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      // Act
      await client.sendQuery(
        'agent-1',
        'Test prompt',
      );

      // Assert - verify that tool2 and tool3 are included (default true)
      final captured = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final bodyStr = captured[2] as String;
      final requestBody = jsonDecode(bodyStr) as Map<String, dynamic>;
      expect(requestBody['tools'], isNotNull);
      final tools = requestBody['tools'] as List;
      final toolNames = tools.map((t) => t['function']['name']).toList();

      expect(toolNames, isNot(contains('tool1'))); // tool1 explicitly false
      expect(
          toolNames, contains('tool2')); // tool2 not in map, defaults to true
      expect(
          toolNames, contains('tool3')); // tool3 not in map, defaults to true
      expect(tools.length, 2);
    });

    test('different agents should have independent tool configurations',
        () async {
      // Arrange
      client.updateAgentTools(
          'agent-1', {'tool1': false, 'tool2': true, 'tool3': true});
      client.updateAgentTools(
          'agent-2', {'tool1': true, 'tool2': false, 'tool3': true});

      final mockResponse = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
            },
          ],
        }),
        200,
      );

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      // Act - query agent-1
      await client.sendQuery('agent-1', 'Test prompt 1');

      final captured1 = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final requestBody1 =
          jsonDecode(captured1[2] as String) as Map<String, dynamic>;
      final tools1 = requestBody1['tools'] as List;
      final toolNames1 = tools1.map((t) => t['function']['name']).toList();

      // Assert agent-1 tools
      expect(toolNames1, isNot(contains('tool1'))); // disabled
      expect(toolNames1, contains('tool2')); // enabled
      expect(toolNames1, contains('tool3')); // enabled

      // Act - query agent-2
      await client.sendQuery('agent-2', 'Test prompt 2');

      final captured2 = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final requestBody2 =
          jsonDecode(captured2.last as String) as Map<String, dynamic>;
      final tools2 = requestBody2['tools'] as List;
      final toolNames2 = tools2.map((t) => t['function']['name']).toList();

      // Assert agent-2 tools (different configuration)
      expect(toolNames2, contains('tool1')); // enabled
      expect(toolNames2, isNot(contains('tool2'))); // disabled
      expect(toolNames2, contains('tool3')); // enabled
    });

    test('updateTools() should update available tools list', () async {
      // Arrange
      final newTools = [
        {
          'type': 'function',
          'function': {
            'name': 'newTool',
            'description': 'New Tool',
            'parameters': {},
          },
        },
      ];

      client.updateTools(newTools);

      final mockResponse = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
            },
          ],
        }),
        200,
      );

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      // Act
      await client.sendQuery('agent-1', 'Test prompt');

      // Assert - verify new tools are used
      final captured = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final requestBody =
          jsonDecode(captured[2] as String) as Map<String, dynamic>;
      final tools = requestBody['tools'] as List;
      expect(tools.length, 1);
      expect(tools[0]['function']['name'], 'newTool');
    });

    test('sendQuery without tools should not include tools in request',
        () async {
      // Arrange
      final clientWithoutTools = TextAgentApiClient(
        httpClient: mockHttpClient,
        initialData: [
          {
            'id': 'agent-3',
            'name': 'Agent Without Tools',
            'provider': 'openai',
            'apiKey': 'test-key',
            'apiIdentifier': 'gpt-4o',
          },
        ],
        availableTools: [], // No tools
      );

      final mockResponse = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': 'Test response',
              },
            },
          ],
        }),
        200,
      );

      when(mockHttpClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => mockResponse);

      // Act
      await clientWithoutTools.sendQuery('agent-3', 'Test prompt');

      // Assert - verify no tools in request
      final captured = verify(mockHttpClient.post(
        captureAny,
        headers: captureAnyNamed('headers'),
        body: captureAnyNamed('body'),
      )).captured;

      final requestBody =
          jsonDecode(captured[2] as String) as Map<String, dynamic>;
      expect(requestBody.containsKey('tools'), false);

      clientWithoutTools.dispose();
    });

    test('listAgents() should return all registered agents', () async {
      // Act
      final agents = await client.listAgents();

      // Assert
      expect(agents.length, 2);
      expect(agents[0]['id'], 'agent-1');
      expect(agents[0]['name'], 'Test Agent 1');
      expect(agents[1]['id'], 'agent-2');
      expect(agents[1]['name'], 'Test Agent 2');
    });
  });

  group('WorkerTextAgent', () {
    test('should correctly parse from JSON', () {
      // Arrange
      final json = {
        'id': 'worker-1',
        'name': 'Worker Agent',
        'description': 'Test worker',
        'provider': 'openai',
        'apiKey': 'test-key',
        'apiIdentifier': 'gpt-4o',
      };

      // Act
      final agent = WorkerTextAgent.fromJson(json);

      // Assert
      expect(agent.id, 'worker-1');
      expect(agent.name, 'Worker Agent');
      expect(agent.description, 'Test worker');
      expect(agent.provider, 'openai');
      expect(agent.apiKey, 'test-key');
      expect(agent.apiIdentifier, 'gpt-4o');
    });

    test('getEndpointUrl() should return correct URL for OpenAI', () {
      // Arrange
      final agent = WorkerTextAgent(
        id: 'test',
        name: 'Test',
        provider: 'openai',
        apiKey: 'key',
        apiIdentifier: 'gpt-4o',
      );

      // Act
      final url = agent.getEndpointUrl();

      // Assert
      expect(url, 'https://api.openai.com/v1/chat/completions');
    });

    test('getModelIdentifier() should return apiIdentifier for OpenAI', () {
      // Arrange
      final agent = WorkerTextAgent(
        id: 'test',
        name: 'Test',
        provider: 'openai',
        apiKey: 'key',
        apiIdentifier: 'gpt-4o',
      );

      // Act
      final model = agent.getModelIdentifier();

      // Assert
      expect(model, 'gpt-4o');
    });

    test('getRequestHeaders() should include Authorization for OpenAI', () {
      // Arrange
      final agent = WorkerTextAgent(
        id: 'test',
        name: 'Test',
        provider: 'openai',
        apiKey: 'test-key',
        apiIdentifier: 'gpt-4o',
      );

      // Act
      final headers = agent.getRequestHeaders();

      // Assert
      expect(headers['Authorization'], 'Bearer test-key');
      expect(headers['Content-Type'], 'application/json');
    });

    test('getRequestHeaders() should include api-key for Azure', () {
      // Arrange
      final agent = WorkerTextAgent(
        id: 'test',
        name: 'Test',
        provider: 'azure',
        apiKey: 'azure-key',
        apiIdentifier: 'https://test.openai.azure.com',
      );

      // Act
      final headers = agent.getRequestHeaders();

      // Assert
      expect(headers['api-key'], 'azure-key');
      expect(headers['Content-Type'], 'application/json');
    });
  });
}
