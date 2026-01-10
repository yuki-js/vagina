import '../models/speed_dial.dart';
import '../interfaces/speed_dial_repository.dart';
import '../interfaces/key_value_store.dart';
import '../services/log_service.dart';

/// JSON-based implementation of SpeedDialRepository
class JsonSpeedDialRepository implements SpeedDialRepository {
  static const _tag = 'SpeedDialRepo';
  static const _speedDialsKey = 'speed_dials';
  
  final KeyValueStore _store;

  JsonSpeedDialRepository(this._store);

  @override
  Future<void> save(SpeedDial speedDial) async {
    logService.debug(_tag, 'Saving speed dial: ${speedDial.id}');
    
    final speedDials = await getAll();
    speedDials.add(speedDial);
    
    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);
    
    logService.info(_tag, 'Speed dial saved: ${speedDial.id}');
  }

  @override
  Future<List<SpeedDial>> getAll() async {
    final data = await _store.get(_speedDialsKey);
    
    if (data == null) {
      return [];
    }
    
    if (data is! List) {
      logService.warn(_tag, 'Invalid speed dials data type');
      return [];
    }
    
    return data
        .map((json) => SpeedDial.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SpeedDial?> getById(String id) async {
    final speedDials = await getAll();
    try {
      return speedDials.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> update(SpeedDial speedDial) async {
    logService.debug(_tag, 'Updating speed dial: ${speedDial.id}');
    
    final speedDials = await getAll();
    final index = speedDials.indexWhere((s) => s.id == speedDial.id);
    
    if (index == -1) {
      logService.warn(_tag, 'Speed dial not found for update: ${speedDial.id}');
      return false;
    }
    
    speedDials[index] = speedDial;
    
    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);
    
    logService.info(_tag, 'Speed dial updated: ${speedDial.id}');
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    logService.debug(_tag, 'Deleting speed dial: $id');
    
    final speedDials = await getAll();
    final initialLength = speedDials.length;
    speedDials.removeWhere((s) => s.id == id);
    
    if (speedDials.length == initialLength) {
      logService.warn(_tag, 'Speed dial not found: $id');
      return false;
    }
    
    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);
    
    logService.info(_tag, 'Speed dial deleted: $id');
    return true;
  }
}
