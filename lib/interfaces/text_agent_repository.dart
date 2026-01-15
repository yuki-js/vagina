import '../models/text_agent.dart';

/// Repository interface for managing text agents
abstract class TextAgentRepository {
  /// Get all available text agents
  Future<List<TextAgent>> getAll();
  
  /// Get a specific text agent by ID
  Future<TextAgent?> getById(String id);
  
  /// Save or update a text agent
  Future<void> save(TextAgent agent);
  
  /// Delete a text agent
  Future<void> delete(String id);
  
  /// Check if an agent exists
  Future<bool> exists(String id);
}
