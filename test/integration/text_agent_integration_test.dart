import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/services/text_agent_job_runner.dart';
import 'package:vagina/repositories/json_text_agent_repository.dart';
import 'package:vagina/repositories/json_text_agent_job_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';

// Mock KeyValueStore for testing
class MockKeyValueStore implements KeyValueStore {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, dynamic>> load() async {
    return Map<String, dynamic>.from(_data);
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    _data.clear();
    _data.addAll(data);
  }

  @override
  Future<void> set(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<dynamic> get(String key) async {
    return _data[key];
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<bool> contains(String key) async {
    return _data.containsKey(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<String> getFilePath() async {
    return 'mock://test.json';
  }
}

void main() {
  group('Text Agent Integration Tests', () {
    late MockKeyValueStore store;
    late JsonTextAgentRepository agentRepo;
    late JsonTextAgentJobRepository jobRepo;
    late TextAgentService textAgentService;
    late TextAgentJobRunner jobRunner;
    late TextAgent testAgent;

    setUp(() async {
      // Create mock store for testing
      store = MockKeyValueStore();
      await store.initialize();

      // Create repositories
      agentRepo = JsonTextAgentRepository(store);
      jobRepo = JsonTextAgentJobRepository(store);

      // Create test agent
      testAgent = TextAgent(
        id: 'test_agent_1',
        name: 'Test Agent',
        description: 'A test agent for integration testing',
        config: const TextAgentConfig(
          provider: TextAgentProvider.azure,
          apiKey: 'test_api_key',
          apiIdentifier: 'https://test.openai.azure.com',
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save test agent
      await agentRepo.save(testAgent);
    });

    tearDown(() async {
      jobRunner.dispose();
    });

    test('Complete flow: Create agent → Query agent (instant) → Get result', () async {
      // Create mock HTTP client that returns success response
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'This is a test response from the agent'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      textAgentService = TextAgentService(httpClient: mockClient);

      // Execute instant query
      final result = await textAgentService.sendInstantQuery(
        testAgent,
        'What is the capital of France?',
      );

      // Verify result
      expect(result, isNotEmpty);
      expect(result, contains('test response'));
    });

    test('Complete flow: Create agent → Query agent (long) → Poll for result', () async {
      // Create mock HTTP client
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Long processing result'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      textAgentService = TextAgentService(httpClient: mockClient);
      jobRunner = TextAgentJobRunner(
        textAgentService: textAgentService,
        agentRepository: agentRepo,
        jobRepository: jobRepo,
      );

      // Submit async job
      final token = await jobRunner.submitJob(
        testAgent,
        'Write a detailed analysis',
        TextAgentExpectLatency.long,
      );

      // Verify token was generated
      expect(token, startsWith('job_'));

      // Get initial job status
      final initialJob = await jobRunner.getJobStatus(token);
      expect(initialJob, isNotNull);
      expect(initialJob!.status, TextAgentJobStatus.pending);

      // Process the job
      await jobRunner.processJob(token);

      // Get final job status
      final finalJob = await jobRunner.getJobStatus(token);
      expect(finalJob, isNotNull);
      expect(finalJob!.status, TextAgentJobStatus.completed);
      expect(finalJob.result, isNotEmpty);
      expect(finalJob.result, contains('Long processing result'));
    });

    test('Complete flow: Create agent → Query agent (ultra_long) → Poll for result', () async {
      // Create mock HTTP client
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Ultra long processing result with detailed analysis'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      textAgentService = TextAgentService(httpClient: mockClient);
      jobRunner = TextAgentJobRunner(
        textAgentService: textAgentService,
        agentRepository: agentRepo,
        jobRepository: jobRepo,
      );

      // Submit ultra long async job
      final token = await jobRunner.submitJob(
        testAgent,
        'Write a comprehensive research report',
        TextAgentExpectLatency.ultraLong,
      );

      // Verify token
      expect(token, startsWith('job_'));

      // Process the job
      await jobRunner.processJob(token);

      // Verify completion
      final job = await jobRunner.getJobStatus(token);
      expect(job, isNotNull);
      expect(job!.status, TextAgentJobStatus.completed);
      expect(job.result, contains('Ultra long processing result'));
    });

    test('Agent selection and switching', () async {
      // Create multiple agents
      final agent2 = TextAgent(
        id: 'test_agent_2',
        name: 'Second Test Agent',
        description: 'Another test agent',
        config: const TextAgentConfig(
          provider: TextAgentProvider.azure,
          apiKey: 'test_api_key_2',
          apiIdentifier: 'https://test2.openai.azure.com',
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await agentRepo.save(agent2);

      // Get all agents
      final agents = await agentRepo.getAll();
      expect(agents.length, equals(2));

      // Verify we can get specific agents
      final retrievedAgent1 = await agentRepo.getById('test_agent_1');
      final retrievedAgent2 = await agentRepo.getById('test_agent_2');

      expect(retrievedAgent1, isNotNull);
      expect(retrievedAgent1!.name, equals('Test Agent'));
      expect(retrievedAgent2, isNotNull);
      expect(retrievedAgent2!.name, equals('Second Test Agent'));
    });

    test('Job expiration and cleanup', () async {
      // Create a job that's already expired
      final expiredJob = TextAgentJob(
        id: 'expired_job_1',
        agentId: testAgent.id,
        prompt: 'Old query',
        expectLatency: TextAgentExpectLatency.instant,
        status: TextAgentJobStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await jobRepo.save(expiredJob);

      // Create job runner
      final mockClient = MockClient((request) async {
        return http.Response('{}', 500);
      });

      textAgentService = TextAgentService(httpClient: mockClient);
      jobRunner = TextAgentJobRunner(
        textAgentService: textAgentService,
        agentRepository: agentRepo,
        jobRepository: jobRepo,
      );

      // Initialize and clean up expired jobs
      await jobRunner.cleanupExpiredJobs();

      // Verify expired job was marked
      final job = await jobRepo.getById('expired_job_1');
      expect(job, isNotNull);
      expect(job!.status, TextAgentJobStatus.expired);
    });

    test('Error handling: Invalid agent', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{}', 200);
      });

      textAgentService = TextAgentService(httpClient: mockClient);
      jobRunner = TextAgentJobRunner(
        textAgentService: textAgentService,
        agentRepository: agentRepo,
        jobRepository: jobRepo,
      );

      // Submit job with invalid agent ID
      final token = await jobRunner.submitJob(
        testAgent,
        'Test query',
        TextAgentExpectLatency.instant,
      );

      // Delete the agent to simulate invalid agent
      await agentRepo.delete(testAgent.id);

      // Try to process - should fail gracefully
      await jobRunner.processJob(token);

      // Verify job was marked as failed
      final job = await jobRunner.getJobStatus(token);
      expect(job, isNotNull);
      expect(job!.status, TextAgentJobStatus.failed);
      expect(job.error, contains('Agent not found'));
    });

    test('Error handling: Network errors', () async {
      // Create mock client that throws network error
      final mockClient = MockClient((request) async {
        throw Exception('Network connection failed');
      });

      textAgentService = TextAgentService(httpClient: mockClient);

      // Attempt instant query - should throw
      expect(
        () => textAgentService.sendInstantQuery(testAgent, 'Test query'),
        throwsException,
      );
    });

    test('Error handling: API timeout', () async {
      // Create mock client that simulates timeout
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(seconds: 2));
        return http.Response('{}', 200);
      });

      textAgentService = TextAgentService(httpClient: mockClient);

      // Attempt query with very short timeout - should throw TimeoutException
      expect(
        () => textAgentService.sendInstantQuery(
          testAgent,
          'Test query',
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Multiple concurrent jobs', () async {
      final mockClient = MockClient((request) async {
        // Simulate variable response times
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Response for ${request.body}'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      textAgentService = TextAgentService(httpClient: mockClient);
      jobRunner = TextAgentJobRunner(
        textAgentService: textAgentService,
        agentRepository: agentRepo,
        jobRepository: jobRepo,
      );

      // Submit multiple jobs
      final tokens = <String>[];
      for (int i = 0; i < 5; i++) {
        final token = await jobRunner.submitJob(
          testAgent,
          'Query $i',
          TextAgentExpectLatency.long,
        );
        tokens.add(token);
      }

      // Verify all jobs were created
      expect(tokens.length, equals(5));

      // Process all jobs
      await jobRunner.processAllPendingJobs();

      // Verify all completed
      for (final token in tokens) {
        final job = await jobRunner.getJobStatus(token);
        expect(job, isNotNull);
        expect(job!.status, TextAgentJobStatus.completed);
      }
    });

    test('Job persistence across restarts', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Persistent result'}
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      textAgentService = TextAgentService(httpClient: mockClient);
      jobRunner = TextAgentJobRunner(
        textAgentService: textAgentService,
        agentRepository: agentRepo,
        jobRepository: jobRepo,
      );

      // Submit a job
      final token = await jobRunner.submitJob(
        testAgent,
        'Persistent query',
        TextAgentExpectLatency.long,
      );

      // Dispose the job runner (simulating app restart)
      jobRunner.dispose();

      // Create a new job runner
      jobRunner = TextAgentJobRunner(
        textAgentService: textAgentService,
        agentRepository: agentRepo,
        jobRepository: jobRepo,
      );

      // Initialize should reload pending jobs
      await jobRunner.initialize();

      // Job should still be retrievable
      final job = await jobRunner.getJobStatus(token);
      expect(job, isNotNull);
      expect(job!.prompt, equals('Persistent query'));
    });
  });
}
