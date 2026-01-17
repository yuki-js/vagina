import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/core/data/json_file_store.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/services/log_service.dart';

import 'json_call_session_repository.dart';
import 'json_config_repository.dart';
import 'json_memory_repository.dart';
import 'json_speed_dial_repository.dart';
import 'preferences_repository.dart';

/// Factory for creating repository instances
///
/// All repositories share a common KeyValueStore for consistent
/// data storage location and initialization.
class RepositoryFactory {
  static KeyValueStore? _store;
  static CallSessionRepository? _callSessionRepo;
  static SpeedDialRepository? _speedDialRepo;
  static MemoryRepository? _memoryRepo;
  static ConfigRepository? _configRepo;
  static PreferencesRepository? _preferencesRepo;
  static LogService? _logService;

  /// Initialize the repositories with a key-value store.
  ///
  /// In widget/unit tests, file IO / platform channels can hang. When running
  /// under test (`bool.fromEnvironment('FLUTTER_TEST') == true`), we default to
  /// an in-memory store.
  static Future<void> initialize(
      {LogService? logService, KeyValueStore? store}) async {
    _logService = logService ?? LogService();

    if (_store != null) return;

    const isFlutterTest = bool.fromEnvironment('FLUTTER_TEST');

    if (store != null) {
      _store = store;
    } else if (isFlutterTest) {
      // Avoid file IO / platform storage services in tests.
      _store = InMemoryStore();
    } else {
      _store = JsonFileStore(
        fileName: 'vagina_config.json',
        folderName: 'VAGINA',
        logService: _logService,
      );
    }

    await _store!.initialize();
  }

  /// Get the CallSession repository
  static CallSessionRepository get callSessions {
    _ensureInitialized();
    return _callSessionRepo ??=
        JsonCallSessionRepository(_store!, logService: _logService);
  }

  /// Get the SpeedDial repository
  static SpeedDialRepository get speedDials {
    _ensureInitialized();
    return _speedDialRepo ??=
        JsonSpeedDialRepository(_store!, logService: _logService);
  }

  /// Get the Memory repository
  static MemoryRepository get memory {
    _ensureInitialized();
    return _memoryRepo ??=
        JsonMemoryRepository(_store!, logService: _logService);
  }

  /// Get the Config repository
  static ConfigRepository get config {
    _ensureInitialized();
    return _configRepo ??=
        JsonConfigRepository(_store!, logService: _logService);
  }

  /// Get the Preferences repository
  static PreferencesRepository get preferences {
    _ensureInitialized();
    return _preferencesRepo ??= PreferencesRepository(_store!);
  }

  /// Helper to ensure initialization
  static void _ensureInitialized() {
    if (_store == null) {
      throw StateError(
          'RepositoryFactory not initialized. Call initialize() first.');
    }
  }

  /// Reset all repositories (for testing)
  static void reset() {
    _store = null;
    _callSessionRepo = null;
    _speedDialRepo = null;
    _memoryRepo = null;
    _configRepo = null;
    _preferencesRepo = null;
    _logService = null;
  }
}
