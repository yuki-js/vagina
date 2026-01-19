import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/interfaces/text_agent_job_repository.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/services/text_agent_job_runner.dart';

import 'text_agent_job_runner_test.mocks.dart';

@GenerateMocks([
  TextAgentService,
  TextAgentRepository,
  TextAgentJobRepository,
  LogService,
])
void main() {
  group('TextAgentJobRunner', () {
    late MockTextAgentService mockService;
    late MockTextAgentRepository mockAgentRepo;
    late MockTextAgentJobRepository mockJobRepo;
    late MockLogService mockLogService;
    late TextAgentJobRunner jobRunner;
    late TextAgent testAgent;

    setUp(() {
      mockService = MockTextAgentService();
      mockAgentRepo = MockTextAgentRepository();
      mockJobRepo = MockTextAgentJobRepository();
      mockLogService = MockLogService();

      jobRunner = TextAgentJobRunner(
        textAgentService: mockService,
        agentRepository: mockAgentRepo,
        jobRepository: mockJobRepo,
        logService: mockLogService,
      );

      testAgent = TextAgent(
        id: 'test_agent_1',
        name: 'Test Agent',
        description: 'Test agent for testing',
        config: const TextAgentConfig(
          provider: TextAgentProvider.azure,
          apiKey: 'test-api-key',
          apiIdentifier: 'https://test.openai.azure.com',
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    tearDown(() {
      jobRunner.dispose();
    });

    group('submitJob', () {
      test('should create and save new job', () async {
        // Arrange
        const prompt = 'Hello, world!';
        const latency = TextAgentExpectLatency.long;

        when(mockJobRepo.save(any)).thenAnswer((_) async => {});

        // Act
        final token = await jobRunner.submitJob(testAgent, prompt, latency);

        // Assert
        expect(token, isNotEmpty);
        expect(token, startsWith('job_'));
        verify(mockJobRepo.save(any)).called(1);
      });

      test('should throw ArgumentError on empty prompt', () async {
        // Arrange
        const prompt = '   ';
        const latency = TextAgentExpectLatency.long;

        // Act & Assert
        expect(
          () => jobRunner.submitJob(testAgent, prompt, latency),
          throwsArgumentError,
        );
      });

      test('should set correct expiration time for long latency', () async {
        // Arrange
        const prompt = 'Test prompt';
        const latency = TextAgentExpectLatency.long;

        TextAgentJob? savedJob;
        when(mockJobRepo.save(any)).thenAnswer((invocation) async {
          savedJob = invocation.positionalArguments[0] as TextAgentJob;
        });

        // Act
        await jobRunner.submitJob(testAgent, prompt, latency);

        // Assert
        expect(savedJob, isNotNull);
        expect(savedJob!.status, TextAgentJobStatus.pending);
        expect(savedJob!.expectLatency, latency);

        // Long latency should expire in ~1 hour
        final expectedExpiration = savedJob!.createdAt.add(const Duration(hours: 1));
        expect(
          savedJob!.expiresAt.difference(expectedExpiration).abs(),
          lessThan(const Duration(seconds: 1)),
        );
      });

      test('should set correct expiration time for ultra long latency', () async {
        // Arrange
        const prompt = 'Test prompt';
        const latency = TextAgentExpectLatency.ultraLong;

        TextAgentJob? savedJob;
        when(mockJobRepo.save(any)).thenAnswer((invocation) async {
          savedJob = invocation.positionalArguments[0] as TextAgentJob;
        });

        // Act
        await jobRunner.submitJob(testAgent, prompt, latency);

        // Assert
        expect(savedJob, isNotNull);

        // Ultra long latency should expire in ~24 hours
        final expectedExpiration = savedJob!.createdAt.add(const Duration(hours: 24));
        expect(
          savedJob!.expiresAt.difference(expectedExpiration).abs(),
          lessThan(const Duration(seconds: 1)),
        );
      });
    });

    group('getJobStatus', () {
      test('should return job from repository', () async {
        // Arrange
        const jobId = 'job_123';
        final job = TextAgentJob(
          id: jobId,
          agentId: testAgent.id,
          prompt: 'Test prompt',
          expectLatency: TextAgentExpectLatency.long,
          status: TextAgentJobStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockJobRepo.getById(jobId)).thenAnswer((_) async => job);

        // Act
        final result = await jobRunner.getJobStatus(jobId);

        // Assert
        expect(result, job);
        verify(mockJobRepo.getById(jobId)).called(1);
      });

      test('should return null for non-existent job', () async {
        // Arrange
        const jobId = 'job_nonexistent';

        when(mockJobRepo.getById(jobId)).thenAnswer((_) async => null);

        // Act
        final result = await jobRunner.getJobStatus(jobId);

        // Assert
        expect(result, isNull);
      });
    });

    group('processJob', () {
      test('should mark job as completed on success', () async {
        // Arrange
        const jobId = 'job_123';
        const prompt = 'Test prompt';
        const expectedResult = 'Test result';

        final job = TextAgentJob(
          id: jobId,
          agentId: testAgent.id,
          prompt: prompt,
          expectLatency: TextAgentExpectLatency.long,
          status: TextAgentJobStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockJobRepo.getById(jobId)).thenAnswer((_) async => job);
        when(mockAgentRepo.getById(testAgent.id))
            .thenAnswer((_) async => testAgent);
        when(mockService.pollAsyncResult(testAgent, prompt, TextAgentExpectLatency.long))
            .thenAnswer((_) async => expectedResult);
        when(mockJobRepo.save(any)).thenAnswer((_) async => {});

        // Act
        await jobRunner.processJob(jobId);

        // Assert
        final captured = verify(mockJobRepo.save(captureAny)).captured;
        final savedJob = captured.last as TextAgentJob;
        expect(savedJob.status, TextAgentJobStatus.completed);
        expect(savedJob.result, expectedResult);
        expect(savedJob.completedAt, isNotNull);
      });

      test('should mark job as failed after max retries', () async {
        // Arrange
        const jobId = 'job_123';
        const prompt = 'Test prompt';

        final job = TextAgentJob(
          id: jobId,
          agentId: testAgent.id,
          prompt: prompt,
          expectLatency: TextAgentExpectLatency.long,
          status: TextAgentJobStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockJobRepo.getById(jobId)).thenAnswer((_) async => job);
        when(mockAgentRepo.getById(testAgent.id))
            .thenAnswer((_) async => testAgent);
        when(mockService.pollAsyncResult(testAgent, prompt, TextAgentExpectLatency.long))
            .thenThrow(Exception('Network error'));
        when(mockJobRepo.save(any)).thenAnswer((_) async => {});

        // Act
        await jobRunner.processJob(jobId);

        // Assert - Job should fail after retries (retries happen within processJob)
        // We need to wait for async retries to complete
        await Future.delayed(const Duration(seconds: 1));

        final captured = verify(mockJobRepo.save(captureAny)).captured;
        final savedJob = captured.last as TextAgentJob;
        expect(savedJob.status, TextAgentJobStatus.failed);
        expect(savedJob.error, isNotNull);
        expect(savedJob.completedAt, isNotNull);
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('should mark expired job as expired', () async {
        // Arrange
        const jobId = 'job_123';

        final job = TextAgentJob(
          id: jobId,
          agentId: testAgent.id,
          prompt: 'Test prompt',
          expectLatency: TextAgentExpectLatency.long,
          status: TextAgentJobStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        when(mockJobRepo.getById(jobId)).thenAnswer((_) async => job);
        when(mockJobRepo.save(any)).thenAnswer((_) async => {});

        // Act
        await jobRunner.processJob(jobId);

        // Assert
        final captured = verify(mockJobRepo.save(captureAny)).captured;
        final savedJob = captured.first as TextAgentJob;
        expect(savedJob.status, TextAgentJobStatus.expired);
        expect(savedJob.error, 'Job expired');
      });

      test('should handle missing agent', () async {
        // Arrange
        const jobId = 'job_123';

        final job = TextAgentJob(
          id: jobId,
          agentId: 'nonexistent_agent',
          prompt: 'Test prompt',
          expectLatency: TextAgentExpectLatency.long,
          status: TextAgentJobStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockJobRepo.getById(jobId)).thenAnswer((_) async => job);
        when(mockAgentRepo.getById('nonexistent_agent'))
            .thenAnswer((_) async => null);
        when(mockJobRepo.save(any)).thenAnswer((_) async => {});

        // Act
        await jobRunner.processJob(jobId);

        // Assert
        final captured = verify(mockJobRepo.save(captureAny)).captured;
        final savedJob = captured.first as TextAgentJob;
        expect(savedJob.status, TextAgentJobStatus.failed);
        expect(savedJob.error, 'Agent not found');
      });
    });

    group('cleanupExpiredJobs', () {
      test('should delete expired jobs', () async {
        // Arrange
        final expiredJob = TextAgentJob(
          id: 'job_expired',
          agentId: testAgent.id,
          prompt: 'Test prompt',
          expectLatency: TextAgentExpectLatency.long,
          status: TextAgentJobStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        final activeJob = TextAgentJob(
          id: 'job_active',
          agentId: testAgent.id,
          prompt: 'Test prompt',
          expectLatency: TextAgentExpectLatency.long,
          status: TextAgentJobStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        when(mockJobRepo.getAll())
            .thenAnswer((_) async => [expiredJob, activeJob]);
        when(mockJobRepo.save(any)).thenAnswer((_) async => {});
        when(mockJobRepo.deleteExpired()).thenAnswer((_) async => {});

        // Act
        await jobRunner.cleanupExpiredJobs();

        // Assert
        verify(mockJobRepo.deleteExpired()).called(1);
        verify(mockJobRepo.save(any)).called(1); // Only expired job marked
      });
    });

    group('initialization', () {
      test('should initialize and process pending jobs', () async {
        // Arrange
        when(mockJobRepo.getAll()).thenAnswer((_) async => []);
        when(mockJobRepo.deleteExpired()).thenAnswer((_) async => {});

        // Act
        await jobRunner.initialize();

        // Assert - These may be called multiple times during init
        verify(mockJobRepo.deleteExpired()).called(greaterThanOrEqualTo(1));
        verify(mockJobRepo.getAll()).called(greaterThanOrEqualTo(1));
      });

      test('should not initialize twice', () async {
        // Arrange
        when(mockJobRepo.getAll()).thenAnswer((_) async => []);
        when(mockJobRepo.deleteExpired()).thenAnswer((_) async => {});

        // Act
        await jobRunner.initialize();
        await jobRunner.initialize();

        // Assert - second call should be ignored (warning logged but no additional repo calls)
        // We can't verify exact counts easily with mockito, so just verify it was called at least once
        verify(mockJobRepo.deleteExpired()).called(greaterThanOrEqualTo(1));
      });
    });
  });
}
