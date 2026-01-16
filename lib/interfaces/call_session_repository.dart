import '../models/call_session.dart';

/// Repository for managing call session data
abstract class CallSessionRepository {
  /// Save a call session
  Future<void> save(CallSession session);

  /// Get all call sessions
  Future<List<CallSession>> getAll();

  /// Get a specific call session by ID
  Future<CallSession?> getById(String id);

  /// Delete a call session
  Future<bool> delete(String id);

  /// Delete all call sessions
  Future<void> deleteAll();
}
