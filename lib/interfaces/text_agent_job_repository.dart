import 'package:vagina/feat/text_agents/model/text_agent_job.dart';

/// Repository for managing text agent job data
abstract class TextAgentJobRepository {
  /// Get all text agent jobs
  Future<List<TextAgentJob>> getAll();

  /// Get a specific text agent job by ID (token)
  Future<TextAgentJob?> getById(String id);

  /// Save a text agent job (create or update)
  Future<void> save(TextAgentJob job);

  /// Delete a text agent job
  Future<void> delete(String id);

  /// Delete all expired jobs
  Future<void> deleteExpired();
}
