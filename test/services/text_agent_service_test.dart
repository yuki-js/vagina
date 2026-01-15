import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/text_agent.dart';
import 'package:vagina/services/text_agent_service.dart';

void main() {
  group('TextAgentService', () {
    late TextAgentService service;

    setUp(() {
      service = TextAgentService();
    });

    tearDown(() {
      service.dispose();
    });

    test('should initialize with default agents', () {
      final agents = service.listAvailableAgents();
      expect(agents, isNotEmpty);
      expect(agents.any((a) => a.id == 'gpt-4o'), isTrue);
      expect(agents.any((a) => a.id == 'o1'), isTrue);
    });

    test('should get agent by ID', () {
      final agent = service.getAgent('gpt-4o');
      expect(agent, isNotNull);
      expect(agent!.name, 'GPT-4o');
    });

    test('should register new agent', () {
      const newAgent = TextAgent(
        id: 'test-agent',
        name: 'Test Agent',
        description: 'Test agent for testing',
        modelIdentifier: 'test-model',
      );

      service.registerAgent(newAgent);
      final retrieved = service.getAgent('test-agent');
      expect(retrieved, equals(newAgent));
    });

    test('should unregister agent', () {
      service.unregisterAgent('gpt-4o');
      final agent = service.getAgent('gpt-4o');
      expect(agent, isNull);
    });

    test('should execute instant query', () async {
      final response = await service.queryTextAgent(
        agentId: 'gpt-4o',
        prompt: 'Test prompt',
        expectLatency: AgentLatency.instant,
      );

      expect(response, isA<TextAgentResponse>());
      expect((response as TextAgentResponse).content, isNotEmpty);
      expect(response.isComplete, isTrue);
    });

    test('should create async query and return request ID', () async {
      final requestId = await service.queryTextAgent(
        agentId: 'gpt-4o',
        prompt: 'Test async prompt',
        expectLatency: AgentLatency.long,
      );

      expect(requestId, isA<String>());
      expect(requestId, isNotEmpty);
    });

    test('should check if query is complete', () async {
      final requestId = await service.queryTextAgent(
        agentId: 'gpt-4o',
        prompt: 'Test',
        expectLatency: AgentLatency.long,
      );

      // Initially not complete
      expect(service.isQueryComplete(requestId), isFalse);
    });

    test('should cancel pending query', () async {
      final requestId = await service.queryTextAgent(
        agentId: 'gpt-4o',
        prompt: 'Test',
        expectLatency: AgentLatency.long,
      );

      service.cancelQuery(requestId);
      expect(service.isQueryComplete(requestId), isFalse);
    });

    test('should throw error for unknown agent', () {
      expect(
        () => service.queryTextAgent(
          agentId: 'unknown-agent',
          prompt: 'Test',
          expectLatency: AgentLatency.instant,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should clear old responses', () async {
      service.clearOldResponses(maxAge: Duration.zero);
      // Should complete without errors
    });
  });

  group('TextAgent model', () {
    test('should create TextAgent from JSON', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Agent',
        'description': 'Test description',
        'modelIdentifier': 'test-model',
        'capabilities': ['test1', 'test2'],
        'isAvailable': true,
      };

      final agent = TextAgent.fromJson(json);
      expect(agent.id, 'test-id');
      expect(agent.name, 'Test Agent');
      expect(agent.capabilities, ['test1', 'test2']);
    });

    test('should convert TextAgent to JSON', () {
      const agent = TextAgent(
        id: 'test-id',
        name: 'Test Agent',
        description: 'Test description',
        modelIdentifier: 'test-model',
      );

      final json = agent.toJson();
      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Agent');
    });

    test('should support equality', () {
      const agent1 = TextAgent(
        id: 'test-id',
        name: 'Test Agent',
        description: 'Test',
        modelIdentifier: 'model',
      );

      const agent2 = TextAgent(
        id: 'test-id',
        name: 'Test Agent',
        description: 'Test',
        modelIdentifier: 'model',
      );

      expect(agent1, equals(agent2));
    });
  });

  group('AgentLatency enum', () {
    test('should convert from string', () {
      expect(AgentLatency.fromString('instant'), AgentLatency.instant);
      expect(AgentLatency.fromString('long'), AgentLatency.long);
      expect(AgentLatency.fromString('ultra_long'), AgentLatency.ultraLong);
    });

    test('should default to instant for unknown value', () {
      expect(AgentLatency.fromString('unknown'), AgentLatency.instant);
    });
  });
}
