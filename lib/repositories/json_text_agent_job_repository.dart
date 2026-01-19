import 'package:vagina/feat/text_agents/model/text_agent_job.dart';
import 'package:vagina/interfaces/text_agent_job_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/services/log_service.dart';

/// JSON-based implementation of TextAgentJobRepository
class JsonTextAgentJobRepository implements TextAgentJobRepository {
  static const _tag = 'TextAgentJobRepo';
  static const _textAgentJobsKey = 'text_agent_jobs';

  final KeyValueStore _store;
  final LogService _logService;

  JsonTextAgentJobRepository(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  @override
  Future<void> save(TextAgentJob job) async {
    _logService.debug(_tag, 'Saving text agent job: ${job.id}');

    final jobs = await getAll();

    // Check if job already exists
    final existingIndex = jobs.indexWhere((j) => j.id == job.id);
    if (existingIndex != -1) {
      // Update existing job
      jobs[existingIndex] = job;
    } else {
      // Add new job
      jobs.add(job);
    }

    final jobsJson = jobs.map((j) => j.toJson()).toList();
    await _store.set(_textAgentJobsKey, jobsJson);

    _logService.info(_tag, 'Text agent job saved: ${job.id}');
  }

  @override
  Future<List<TextAgentJob>> getAll() async {
    final data = await _store.get(_textAgentJobsKey);

    if (data == null || data is! List) {
      if (data != null && data is! List) {
        _logService.warn(_tag, 'Invalid text agent jobs data type');
      }
      return [];
    }

    try {
      return data
          .map((json) => TextAgentJob.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logService.error(_tag, 'Error parsing text agent jobs: $e');
      return [];
    }
  }

  @override
  Future<TextAgentJob?> getById(String id) async {
    final jobs = await getAll();
    try {
      return jobs.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String id) async {
    _logService.debug(_tag, 'Deleting text agent job: $id');

    final jobs = await getAll();
    final initialLength = jobs.length;
    jobs.removeWhere((j) => j.id == id);

    if (jobs.length == initialLength) {
      _logService.warn(_tag, 'Text agent job not found: $id');
      return;
    }

    final jobsJson = jobs.map((j) => j.toJson()).toList();
    await _store.set(_textAgentJobsKey, jobsJson);

    _logService.info(_tag, 'Text agent job deleted: $id');
  }

  @override
  Future<void> deleteExpired() async {
    _logService.debug(_tag, 'Deleting expired text agent jobs');

    final jobs = await getAll();
    final now = DateTime.now();
    final initialLength = jobs.length;

    // Remove expired jobs
    jobs.removeWhere((j) => j.expiresAt.isBefore(now));

    if (jobs.length < initialLength) {
      final jobsJson = jobs.map((j) => j.toJson()).toList();
      await _store.set(_textAgentJobsKey, jobsJson);
      _logService.info(
        _tag,
        'Deleted ${initialLength - jobs.length} expired text agent jobs',
      );
    } else {
      _logService.debug(_tag, 'No expired jobs to delete');
    }
  }
}
