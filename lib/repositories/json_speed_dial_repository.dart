import '../models/speed_dial.dart';
import '../interfaces/speed_dial_repository.dart';
import '../interfaces/key_value_store.dart';
import '../services/log_service.dart';

/// JSON-based implementation of SpeedDialRepository
class JsonSpeedDialRepository implements SpeedDialRepository {
  static const _tag = 'SpeedDialRepo';
  static const _speedDialsKey = 'speed_dials';

  final KeyValueStore _store;
  final LogService _logService;

  JsonSpeedDialRepository(this._store, {LogService? logService})
      : _logService = logService ?? LogService();

  @override
  Future<void> save(SpeedDial speedDial) async {
    _logService.debug(_tag, 'Saving speed dial: ${speedDial.id}');

    final speedDials = await getAll();
    speedDials.add(speedDial);

    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);

    _logService.info(_tag, 'Speed dial saved: ${speedDial.id}');
  }

  @override
  Future<List<SpeedDial>> getAll() async {
    final data = await _store.get(_speedDialsKey);

    List<SpeedDial> speedDials;
    if (data == null || data is! List) {
      if (data != null && data is! List) {
        _logService.warn(_tag, 'Invalid speed dials data type');
      }
      speedDials = [];
    } else {
      speedDials = data
          .map((json) => SpeedDial.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // Ensure default speed dial always exists
    final hasDefault = speedDials.any((s) => s.id == SpeedDial.defaultId);
    if (!hasDefault) {
      _logService.info(_tag, 'Default speed dial not found, creating it');
      speedDials.insert(0, SpeedDial.defaultSpeedDial);
      // Save the updated list with default
      final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
      await _store.set(_speedDialsKey, speedDialsJson);
    }

    return speedDials;
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
    _logService.debug(_tag, 'Updating speed dial: ${speedDial.id}');

    // Prevent renaming the default speed dial
    if (speedDial.id == SpeedDial.defaultId) {
      final existing = await getById(SpeedDial.defaultId);
      if (existing != null && speedDial.name != existing.name) {
        _logService.warn(_tag, 'Cannot rename default speed dial');
        return false;
      }
    }

    final speedDials = await getAll();
    final index = speedDials.indexWhere((s) => s.id == speedDial.id);

    if (index == -1) {
      _logService.warn(
          _tag, 'Speed dial not found for update: ${speedDial.id}');
      return false;
    }

    speedDials[index] = speedDial;

    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);

    _logService.info(_tag, 'Speed dial updated: ${speedDial.id}');
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    _logService.debug(_tag, 'Deleting speed dial: $id');

    // Prevent deletion of default speed dial
    if (id == SpeedDial.defaultId) {
      _logService.warn(_tag, 'Cannot delete default speed dial');
      return false;
    }

    final speedDials = await getAll();
    final initialLength = speedDials.length;
    speedDials.removeWhere((s) => s.id == id);

    if (speedDials.length == initialLength) {
      _logService.warn(_tag, 'Speed dial not found: $id');
      return false;
    }

    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);

    _logService.info(_tag, 'Speed dial deleted: $id');
    return true;
  }
}
