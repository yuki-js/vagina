import '../data/key_value_store.dart';
import '../data/json_file_store.dart';
import 'call_session_repository.dart';
import 'speed_dial_repository.dart';
import 'memory_repository.dart';
import 'config_repository.dart';
import 'json_call_session_repository.dart';
import 'json_speed_dial_repository.dart';
import 'json_memory_repository.dart';
import 'json_config_repository.dart';

/// Factory for creating repository instances
class RepositoryFactory {
  static KeyValueStore? _store;
  static CallSessionRepository? _callSessionRepo;
  static SpeedDialRepository? _speedDialRepo;
  static MemoryRepository? _memoryRepo;
  static ConfigRepository? _configRepo;

  /// Initialize the repositories with a key-value store
  static Future<void> initialize() async {
    _store ??= JsonFileStore(
      fileName: 'vagina_config.json',
      folderName: 'VAGINA',
    );
    await _store!.initialize();
  }

  /// Get the CallSession repository
  static CallSessionRepository get callSessions {
    if (_store == null) {
      throw StateError('RepositoryFactory not initialized. Call initialize() first.');
    }
    return _callSessionRepo ??= JsonCallSessionRepository(_store!);
  }

  /// Get the SpeedDial repository
  static SpeedDialRepository get speedDials {
    if (_store == null) {
      throw StateError('RepositoryFactory not initialized. Call initialize() first.');
    }
    return _speedDialRepo ??= JsonSpeedDialRepository(_store!);
  }

  /// Get the Memory repository
  static MemoryRepository get memory {
    if (_store == null) {
      throw StateError('RepositoryFactory not initialized. Call initialize() first.');
    }
    return _memoryRepo ??= JsonMemoryRepository(_store!);
  }

  /// Get the Config repository
  static ConfigRepository get config {
    if (_store == null) {
      throw StateError('RepositoryFactory not initialized. Call initialize() first.');
    }
    return _configRepo ??= JsonConfigRepository(_store!);
  }

  /// Reset all repositories (for testing)
  static void reset() {
    _store = null;
    _callSessionRepo = null;
    _speedDialRepo = null;
    _memoryRepo = null;
    _configRepo = null;
  }
}
