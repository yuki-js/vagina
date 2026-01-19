import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';
import 'package:vagina/repositories/json_text_agent_repository.dart';
import 'package:vagina/repositories/json_text_agent_job_repository.dart';
import 'package:vagina/services/log_service.dart';

void main() {
  late InMemoryStore store;
  late LogService logService;

  setUp(() {
    store = InMemoryStore();
    logService = LogService();
  });

  group('JsonTextAgentRepository', () {
    late JsonTextAgentRepository repository;

    setUp(() async {
      await store.initialize();
      repository = JsonTextAgentRepository(store, logService: logService);
    });

    test('should save and retrieve text agent', () async {
      final config = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-api-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );

      final agent = TextAgent(
        id: 'agent-1',
        name: 'Test Agent',
        description: 'A test agent',
        config: config,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.save(agent);

      final retrieved = await repository.getById('agent-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, agent.id);
      expect(retrieved.name, agent.name);
      expect(retrieved.description, agent.description);
    });

    test('should get all text agents', () async {
      final config = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-api-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );

      final agent1 = TextAgent(
        id: 'agent-1',
        name: 'Test Agent 1',
        config: config,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final agent2 = TextAgent(
        id: 'agent-2',
        name: 'Test Agent 2',
        config: config,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.save(agent1);
      await repository.save(agent2);

      final agents = await repository.getAll();
      expect(agents.length, 2);
      expect(agents.any((a) => a.id == 'agent-1'), true);
      expect(agents.any((a) => a.id == 'agent-2'), true);
    });

    test('should update existing text agent', () async {
      final config = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-api-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );

      final agent = TextAgent(
        id: 'agent-1',
        name: 'Test Agent',
        config: config,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.save(agent);

      final updated = agent.copyWith(name: 'Updated Agent');
      await repository.save(updated);

      final agents = await repository.getAll();
      expect(agents.length, 1);
      expect(agents[0].name, 'Updated Agent');
    });

    test('should delete text agent', () async {
      final config = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-api-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );

      final agent = TextAgent(
        id: 'agent-1',
        name: 'Test Agent',
        config: config,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.save(agent);
      await repository.delete('agent-1');

      final retrieved = await repository.getById('agent-1');
      expect(retrieved, isNull);
    });

    test('should manage selected agent ID', () async {
      await repository.setSelectedAgentId('agent-1');
      final selectedId = await repository.getSelectedAgentId();
      expect(selectedId, 'agent-1');

      await repository.setSelectedAgentId(null);
      final clearedId = await repository.getSelectedAgentId();
      expect(clearedId, isNull);
    });

    test('should clear selected agent ID when deleting selected agent', () async {
      final config = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-api-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );

      final agent = TextAgent(
        id: 'agent-1',
        name: 'Test Agent',
        config: config,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.save(agent);
      await repository.setSelectedAgentId('agent-1');

      await repository.delete('agent-1');

      final selectedId = await repository.getSelectedAgentId();
      expect(selectedId, isNull);
    });
  });

  group('JsonTextAgentJobRepository', () {
    late JsonTextAgentJobRepository repository;

    setUp(() async {
      await store.initialize();
      repository = JsonTextAgentJobRepository(store, logService: logService);
    });

    test('should save and retrieve text agent job', () async {
      final now = DateTime.now();
      final job = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Test prompt',
        expectLatency: TextAgentExpectLatency.long,
        status: TextAgentJobStatus.pending,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await repository.save(job);

      final retrieved = await repository.getById('job-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, job.id);
      expect(retrieved.agentId, job.agentId);
      expect(retrieved.prompt, job.prompt);
      expect(retrieved.status, job.status);
    });

    test('should get all text agent jobs', () async {
      final now = DateTime.now();
      final job1 = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Test prompt 1',
        expectLatency: TextAgentExpectLatency.long,
        status: TextAgentJobStatus.pending,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      final job2 = TextAgentJob(
        id: 'job-2',
        agentId: 'agent-1',
        prompt: 'Test prompt 2',
        expectLatency: TextAgentExpectLatency.instant,
        status: TextAgentJobStatus.completed,
        result: 'Test result',
        createdAt: now,
        completedAt: now.add(const Duration(seconds: 5)),
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await repository.save(job1);
      await repository.save(job2);

      final jobs = await repository.getAll();
      expect(jobs.length, 2);
      expect(jobs.any((j) => j.id == 'job-1'), true);
      expect(jobs.any((j) => j.id == 'job-2'), true);
    });

    test('should update existing text agent job', () async {
      final now = DateTime.now();
      final job = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Test prompt',
        expectLatency: TextAgentExpectLatency.long,
        status: TextAgentJobStatus.pending,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await repository.save(job);

      final updated = job.copyWith(
        status: TextAgentJobStatus.completed,
        result: 'Test result',
        completedAt: now.add(const Duration(seconds: 30)),
      );
      await repository.save(updated);

      final jobs = await repository.getAll();
      expect(jobs.length, 1);
      expect(jobs[0].status, TextAgentJobStatus.completed);
      expect(jobs[0].result, 'Test result');
    });

    test('should delete text agent job', () async {
      final now = DateTime.now();
      final job = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Test prompt',
        expectLatency: TextAgentExpectLatency.long,
        status: TextAgentJobStatus.pending,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await repository.save(job);
      await repository.delete('job-1');

      final retrieved = await repository.getById('job-1');
      expect(retrieved, isNull);
    });

    test('should delete expired jobs', () async {
      final now = DateTime.now();
      final expiredJob = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Expired job',
        expectLatency: TextAgentExpectLatency.long,
        status: TextAgentJobStatus.pending,
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );

      final activeJob = TextAgentJob(
        id: 'job-2',
        agentId: 'agent-1',
        prompt: 'Active job',
        expectLatency: TextAgentExpectLatency.long,
        status: TextAgentJobStatus.pending,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await repository.save(expiredJob);
      await repository.save(activeJob);

      await repository.deleteExpired();

      final jobs = await repository.getAll();
      expect(jobs.length, 1);
      expect(jobs[0].id, 'job-2');
    });
  });
}
