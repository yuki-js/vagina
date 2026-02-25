import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/text_agent_job_repository.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/core/state/repository_providers.dart';

/// Manages background execution of async text agent jobs with persistence
class TextAgentJobRunner {
  static const _tag = 'TextAgentJobRunner';

  final TextAgentService _textAgentService;
  final ConfigRepository _configRepository;
  final TextAgentJobRepository _jobRepository;
  final LogService _logService;

  Timer? _processingTimer;
  bool _isProcessing = false;
  bool _isInitialized = false;

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  // Processing interval
  static const Duration _processingInterval = Duration(seconds: 10);

  TextAgentJobRunner({
    required TextAgentService textAgentService,
    required ConfigRepository configRepository,
    required TextAgentJobRepository jobRepository,
    LogService? logService,
  })  : _textAgentService = textAgentService,
        _configRepository = configRepository,
        _jobRepository = jobRepository,
        _logService = logService ?? LogService();

  /// Initialize the job runner on app startup
  ///
  /// This should be called once during app initialization
  Future<void> initialize() async {
    if (_isInitialized) {
      _logService.warn(_tag, 'Job runner already initialized');
      return;
    }

    _logService.info(_tag, 'Initializing job runner');

    try {
      // Clean up expired jobs
      await cleanupExpiredJobs();

      // Process all pending jobs
      await processAllPendingJobs();

      // Start periodic processing
      _startPeriodicProcessing();

      _isInitialized = true;
      _logService.info(_tag, 'Job runner initialized successfully');
    } catch (e) {
      _logService.error(_tag, 'Failed to initialize job runner: $e');
      rethrow;
    }
  }

  /// Submit a new async job
  ///
  /// Returns the job token
  Future<String> submitJob(
    TextAgent agent,
    String prompt,
    TextAgentExpectLatency latency,
  ) async {
    _logService.info(
      _tag,
      'Submitting new job for agent: ${agent.name}, latency: ${latency.value}',
    );

    // Validate prompt
    if (prompt.trim().isEmpty) {
      throw ArgumentError('Prompt cannot be empty');
    }

    // Generate job token
    final token = _generateJobToken();

    // Calculate expiration time
    final now = DateTime.now();
    final expiresAt = _calculateExpirationTime(now, latency);

    // Create job
    final job = TextAgentJob(
      id: token,
      agentId: agent.id,
      prompt: prompt,
      expectLatency: latency,
      status: TextAgentJobStatus.pending,
      createdAt: now,
      expiresAt: expiresAt,
    );

    // Save job to repository
    await _jobRepository.save(job);

    _logService.info(_tag, 'Job submitted: $token');

    // Trigger immediate processing (non-blocking)
    unawaited(_processNextPendingJob());

    return token;
  }

  /// Get the current status of a job
  Future<TextAgentJob?> getJobStatus(String jobId) async {
    _logService.debug(_tag, 'Getting job status: $jobId');
    return await _jobRepository.getById(jobId);
  }

  /// Process a specific job by ID
  Future<void> processJob(String jobId) async {
    _logService.info(_tag, 'Processing job: $jobId');

    final job = await _jobRepository.getById(jobId);
    if (job == null) {
      _logService.warn(_tag, 'Job not found: $jobId');
      return;
    }

    // Check if job is already completed or failed
    if (job.status == TextAgentJobStatus.completed ||
        job.status == TextAgentJobStatus.failed) {
      _logService.debug(_tag, 'Job already finished: $jobId');
      return;
    }

    // Check if job has expired
    if (DateTime.now().isAfter(job.expiresAt)) {
      _logService.warn(_tag, 'Job expired: $jobId');
      await _markJobExpired(job);
      return;
    }

    // Get the agent
    final agent = await _configRepository.getTextAgentById(job.agentId);
    if (agent == null) {
      _logService.error(_tag, 'Agent not found for job: $jobId');
      await _markJobFailed(job, 'Agent not found');
      return;
    }

    // Execute job with retry logic
    await _executeJobWithRetry(job, agent);
  }

  /// Process all pending and running jobs
  Future<void> processAllPendingJobs() async {
    if (_isProcessing) {
      _logService.debug(_tag, 'Already processing jobs');
      return;
    }

    _isProcessing = true;

    try {
      _logService.debug(_tag, 'Processing all pending jobs');

      final jobs = await _jobRepository.getAll();
      final now = DateTime.now();

      // Filter for pending and running jobs
      final activeJobs = jobs.where((job) {
        return job.status == TextAgentJobStatus.pending ||
            job.status == TextAgentJobStatus.running;
      }).toList();

      if (activeJobs.isEmpty) {
        _logService.debug(_tag, 'No pending jobs to process');
        return;
      }

      _logService.info(_tag, 'Found ${activeJobs.length} active jobs');

      // Process each job
      for (final job in activeJobs) {
        // Check if expired
        if (now.isAfter(job.expiresAt)) {
          await _markJobExpired(job);
          continue;
        }

        // Process the job
        await processJob(job.id);
      }

      _logService.info(_tag, 'Finished processing all pending jobs');
    } catch (e) {
      _logService.error(_tag, 'Error processing pending jobs: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Clean up expired jobs from storage
  Future<void> cleanupExpiredJobs() async {
    _logService.info(_tag, 'Cleaning up expired jobs');

    try {
      final jobs = await _jobRepository.getAll();
      final now = DateTime.now();
      int expiredCount = 0;

      for (final job in jobs) {
        if (now.isAfter(job.expiresAt)) {
          // Mark as expired if not already
          if (job.status != TextAgentJobStatus.expired) {
            await _markJobExpired(job);
          }
          expiredCount++;
        }
      }

      // Delete expired jobs (optional: keep for history)
      await _jobRepository.deleteExpired();

      _logService.info(_tag, 'Cleaned up $expiredCount expired jobs');
    } catch (e) {
      _logService.error(_tag, 'Error cleaning up expired jobs: $e');
    }
  }

  /// Execute a job with retry logic and exponential backoff
  Future<void> _executeJobWithRetry(
    TextAgentJob job,
    TextAgent agent, {
    int retryCount = 0,
  }) async {
    _logService.debug(
      _tag,
      'Executing job ${job.id}, attempt ${retryCount + 1}/$_maxRetries',
    );

    // Update job status to running
    if (job.status != TextAgentJobStatus.running) {
      final updatedJob = job.copyWith(status: TextAgentJobStatus.running);
      await _jobRepository.save(updatedJob);
    }

    try {
      // Execute the query
      final result = await _textAgentService.pollAsyncResult(
        agent,
        job.prompt,
        job.expectLatency,
      );

      if (result != null) {
        // Job completed successfully
        await _markJobCompleted(job, result);
        _logService.info(_tag, 'Job completed: ${job.id}');
      } else {
        // This shouldn't happen with current implementation, but handle it
        _logService.warn(_tag, 'Job returned null result: ${job.id}');
        await _markJobFailed(job, 'No result returned');
      }
    } catch (e) {
      _logService.error(
        _tag,
        'Job execution failed (attempt ${retryCount + 1}): $e',
      );

      // Check if we should retry
      if (retryCount < _maxRetries - 1) {
        // Calculate exponential backoff delay
        final delaySeconds = _initialRetryDelay.inSeconds * (1 << retryCount);
        final delay = Duration(seconds: delaySeconds);
        final cappedDelay = delay > _maxRetryDelay ? _maxRetryDelay : delay;

        _logService.info(
          _tag,
          'Retrying job ${job.id} in ${cappedDelay.inSeconds}s',
        );

        // Wait before retry
        await Future.delayed(cappedDelay);

        // Retry
        await _executeJobWithRetry(job, agent, retryCount: retryCount + 1);
      } else {
        // Max retries reached, mark as failed
        _logService.error(
          _tag,
          'Job failed after $_maxRetries attempts: ${job.id}',
        );
        await _markJobFailed(job, 'Max retries reached: $e');
      }
    }
  }

  /// Mark job as completed with result
  Future<void> _markJobCompleted(TextAgentJob job, String result) async {
    final updatedJob = job.copyWith(
      status: TextAgentJobStatus.completed,
      result: result,
      completedAt: DateTime.now(),
    );
    await _jobRepository.save(updatedJob);
  }

  /// Mark job as failed with error message
  Future<void> _markJobFailed(TextAgentJob job, String error) async {
    final updatedJob = job.copyWith(
      status: TextAgentJobStatus.failed,
      error: error,
      completedAt: DateTime.now(),
    );
    await _jobRepository.save(updatedJob);
  }

  /// Mark job as expired
  Future<void> _markJobExpired(TextAgentJob job) async {
    final updatedJob = job.copyWith(
      status: TextAgentJobStatus.expired,
      error: 'Job expired',
      completedAt: DateTime.now(),
    );
    await _jobRepository.save(updatedJob);
  }

  /// Process the next pending job (non-blocking)
  Future<void> _processNextPendingJob() async {
    try {
      final jobs = await _jobRepository.getAll();
      final pendingJobs = jobs
          .where((job) => job.status == TextAgentJobStatus.pending)
          .toList();

      if (pendingJobs.isNotEmpty) {
        final job = pendingJobs.first;
        await processJob(job.id);
      }
    } catch (e) {
      _logService.error(_tag, 'Error processing next pending job: $e');
    }
  }

  /// Start periodic job processing
  void _startPeriodicProcessing() {
    _logService.debug(_tag, 'Starting periodic job processing');

    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_processingInterval, (_) {
      unawaited(processAllPendingJobs());
    });
  }

  /// Stop periodic job processing
  void _stopPeriodicProcessing() {
    _logService.debug(_tag, 'Stopping periodic job processing');
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  /// Generate a unique job token
  String _generateJobToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'job_${timestamp}_$random';
  }

  /// Calculate expiration time based on latency tier
  DateTime _calculateExpirationTime(
    DateTime startTime,
    TextAgentExpectLatency latency,
  ) {
    switch (latency) {
      case TextAgentExpectLatency.instant:
        return startTime.add(const Duration(minutes: 5));
      case TextAgentExpectLatency.long:
        return startTime.add(const Duration(hours: 1));
      case TextAgentExpectLatency.ultraLong:
        return startTime.add(const Duration(hours: 24));
    }
  }

  /// Dispose the job runner
  void dispose() {
    _logService.debug(_tag, 'Disposing job runner');
    _stopPeriodicProcessing();
    _isInitialized = false;
  }
}

/// Provider for TextAgentJobRunner
final textAgentJobRunnerProvider = Provider<TextAgentJobRunner>((ref) {
  final service = TextAgentJobRunner(
    textAgentService: ref.watch(textAgentServiceProvider),
    configRepository: ref.watch(configRepositoryProvider),
    jobRepository: ref.watch(textAgentJobRepositoryProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});
