import 'package:vagina/feat/text_agents/model/text_agent.dart';

/// Repository for managing text agent data
abstract class TextAgentRepository {
  /// Get all text agents
  Future<List<TextAgent>> getAll();

  /// Get a specific text agent by ID
  Future<TextAgent?> getById(String id);

  /// Save a text agent (create or update)
  Future<void> save(TextAgent agent);

  /// Delete a text agent
  Future<void> delete(String id);

  /// Get the selected agent ID
  Future<String?> getSelectedAgentId();

  /// Set the selected agent ID
  Future<void> setSelectedAgentId(String? id);
}
