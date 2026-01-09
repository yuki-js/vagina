import 'memory_repository.dart';
import '../data/key_value_store.dart';
import '../services/log_service.dart';

/// JSON-based implementation of MemoryRepository
class JsonMemoryRepository implements MemoryRepository {
  static const _tag = 'MemoryRepo';
  static const _memoriesKey = 'memories';
  
  final KeyValueStore _store;

  JsonMemoryRepository(this._store);

  @override
  Future<void> save(String key, String value) async {
    logService.debug(_tag, 'Saving memory: $key');
    
    final memories = await getAll();
    memories[key] = value;
    
    await _store.set(_memoriesKey, memories);
    logService.info(_tag, 'Memory saved: $key');
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
      logService.warn(_tag, 'Invalid memories data type');
      return {};
    }
    
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<bool> delete(String key) async {
    logService.debug(_tag, 'Deleting memory: $key');
    
    final memories = await getAll();
    
    if (!memories.containsKey(key)) {
      logService.warn(_tag, 'Memory not found: $key');
      return false;
    }
    
    memories.remove(key);
    await _store.set(_memoriesKey, memories);
    
    logService.info(_tag, 'Memory deleted: $key');
    return true;
  }

  @override
  Future<void> deleteAll() async {
    logService.info(_tag, 'Deleting all memories');
    await _store.delete(_memoriesKey);
  }
}
