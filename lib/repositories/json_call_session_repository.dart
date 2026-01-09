import '../models/call_session.dart';
import '../interfaces/call_session_repository.dart';
import '../interfaces/key_value_store.dart';
import '../services/log_service.dart';

/// JSON-based implementation of CallSessionRepository
class JsonCallSessionRepository implements CallSessionRepository {
  static const _tag = 'CallSessionRepo';
  static const _sessionsKey = 'call_sessions';
  
  final KeyValueStore _store;

  JsonCallSessionRepository(this._store);

  @override
  Future<void> save(CallSession session) async {
    logService.debug(_tag, 'Saving session: ${session.id}');
    
    final sessions = await getAll();
    sessions.add(session);
    
    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await _store.set(_sessionsKey, sessionsJson);
    
    logService.info(_tag, 'Session saved: ${session.id}');
  }

  @override
  Future<List<CallSession>> getAll() async {
    final data = await _store.get(_sessionsKey);
    
    if (data == null) {
      return [];
    }
    
    if (data is! List) {
      logService.warn(_tag, 'Invalid sessions data type');
      return [];
    }
    
    return data
        .map((json) => CallSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CallSession?> getById(String id) async {
    final sessions = await getAll();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> delete(String id) async {
    logService.debug(_tag, 'Deleting session: $id');
    
    final sessions = await getAll();
    final initialLength = sessions.length;
    sessions.removeWhere((s) => s.id == id);
    
    if (sessions.length == initialLength) {
      logService.warn(_tag, 'Session not found: $id');
      return false;
    }
    
    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await _store.set(_sessionsKey, sessionsJson);
    
    logService.info(_tag, 'Session deleted: $id');
    return true;
  }

  @override
  Future<void> deleteAll() async {
    logService.info(_tag, 'Deleting all sessions');
    await _store.delete(_sessionsKey);
  }
}
