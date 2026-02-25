import 'package:vagina/models/speed_dial.dart';

/// Repository for managing speed dial data
abstract class SpeedDialRepository {
  /// Save a speed dial entry
  Future<void> save(SpeedDial speedDial);

  /// Get all speed dials
  Future<List<SpeedDial>> getAll();

  /// Get a specific speed dial by ID
  Future<SpeedDial?> getById(String id);

  /// Update a speed dial
  Future<bool> update(SpeedDial speedDial);

  /// Delete a speed dial
  Future<bool> delete(String id);
}
