import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:logging/logging.dart';

/// JSON-based implementation of SpeedDialRepository
class JsonSpeedDialRepository implements SpeedDialRepository {
  static const _speedDialsKey = 'speed_dials';

  static final Logger _logger = Logger('JsonSpeedDialRepository');

  final KeyValueStore _store;

  JsonSpeedDialRepository(this._store);

  @override
  Future<void> save(SpeedDial speedDial) async {
    _logger.fine('Saving speed dial: ${speedDial.id}');

    final speedDials = await getAll();
    speedDials.add(speedDial);

    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);

    _logger.info('Speed dial saved: ${speedDial.id}');
  }

  @override
  Future<List<SpeedDial>> getAll() async {
    final data = await _store.get(_speedDialsKey);

    List<SpeedDial> speedDials;
    if (data == null || data is! List) {
      if (data != null && data is! List) {
        _logger.warning('Invalid speed dials data type');
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
      _logger.info('Default speed dial not found, creating it');
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
    _logger.fine('Updating speed dial: ${speedDial.id}');

    // Prevent renaming the default speed dial
    if (speedDial.id == SpeedDial.defaultId) {
      final existing = await getById(SpeedDial.defaultId);
      if (existing != null && speedDial.name != existing.name) {
        _logger.warning('Cannot rename default speed dial');
        return false;
      }
    }

    final speedDials = await getAll();
    final index = speedDials.indexWhere((s) => s.id == speedDial.id);

    if (index == -1) {
      _logger.warning('Speed dial not found for update: ${speedDial.id}');
      return false;
    }

    speedDials[index] = speedDial;

    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);

    _logger.info('Speed dial updated: ${speedDial.id}');
    return true;
  }

  @override
  Future<bool> delete(String id) async {
    _logger.fine('Deleting speed dial: $id');

    // Prevent deletion of default speed dial
    if (id == SpeedDial.defaultId) {
      _logger.warning('Cannot delete default speed dial');
      return false;
    }

    final speedDials = await getAll();
    final initialLength = speedDials.length;
    speedDials.removeWhere((s) => s.id == id);

    if (speedDials.length == initialLength) {
      _logger.warning('Speed dial not found: $id');
      return false;
    }

    final speedDialsJson = speedDials.map((s) => s.toJson()).toList();
    await _store.set(_speedDialsKey, speedDialsJson);

    _logger.info('Speed dial deleted: $id');
    return true;
  }
}
