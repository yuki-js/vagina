import 'package:vagina/models/call_session.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:logging/logging.dart';

/// JSON-based implementation of CallSessionRepository
class JsonCallSessionRepository implements CallSessionRepository {
  static const _sessionsKey = 'call_sessions';

  static final Logger _logger = Logger('JsonCallSessionRepository');

  final KeyValueStore _store;

  JsonCallSessionRepository(this._store);

  @override
  Future<void> save(CallSession session) async {
    _logger.fine('Saving session: ${session.id}');

    final sessions = await getAll();
    sessions.add(session);

    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await _store.set(_sessionsKey, sessionsJson);

    _logger.info('Session saved: ${session.id}');
  }

  @override
  Future<List<CallSession>> getAll() async {
    final data = await _store.get(_sessionsKey);

    if (data == null) {
      return [];
    }

    if (data is! List) {
      _logger.warning('Invalid sessions data type');
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
    _logger.fine('Deleting session: $id');

    final sessions = await getAll();
    final initialLength = sessions.length;
    sessions.removeWhere((s) => s.id == id);

    if (sessions.length == initialLength) {
      _logger.warning('Session not found: $id');
      return false;
    }

    final sessionsJson = sessions.map((s) => s.toJson()).toList();
    await _store.set(_sessionsKey, sessionsJson);

    _logger.info('Session deleted: $id');
    return true;
  }

  @override
  Future<void> deleteAll() async {
    _logger.info('Deleting all sessions');
    await _store.delete(_sessionsKey);
  }
}
