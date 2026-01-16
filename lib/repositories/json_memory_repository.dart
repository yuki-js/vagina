import '../interfaces/memory_repository.dart';
import '../interfaces/key_value_store.dart';
import '../services/log_service.dart';

/// JSON-based implementation of MemoryRepository
class JsonMemoryRepository implements MemoryRepository {
  static const _tag = 'MemoryRepo';
  static const _memoriesKey = 'memories';

  final KeyValueStore _store;
  final LogService _logService;

  JsonMemoryRepository(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  @override
  Future<void> save(String key, String value) async {
    _logService.debug(_tag, 'Saving memory: $key');

    final memories = await getAll();
    memories[key] = value;

    await _store.set(_memoriesKey, memories);
    _logService.info(_tag, 'Memory saved: $key');
  }

  @override
  Future<String?> get(String key) async {
    final memories = await getAll();
    return memories[key] as String?;
  }

  @override
  Future<Map<String, dynamic>> getAll() async {
    final data = await _store.get(_memoriesKey);

    if (data == null) {
      return {};
    }

    if (data is! Map) {
      _logService.warn(_tag, 'Invalid memories data type');
      return {};
    }

    return Map<String, dynamic>.from(data);
  }

  @override
  Future<bool> delete(String key) async {
    _logService.debug(_tag, 'Deleting memory: $key');

    final memories = await getAll();

    if (!memories.containsKey(key)) {
      _logService.warn(_tag, 'Memory not found: $key');
      return false;
    }

    memories.remove(key);
    await _store.set(_memoriesKey, memories);

    _logService.info(_tag, 'Memory deleted: $key');
    return true;
  }

  @override
  Future<void> deleteAll() async {
    _logService.info(_tag, 'Deleting all memories');
    await _store.delete(_memoriesKey);
  }
}
