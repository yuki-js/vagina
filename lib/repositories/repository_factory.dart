import '../interfaces/key_value_store.dart';
import '../data/json_file_store.dart';
import '../interfaces/call_session_repository.dart';
import '../interfaces/speed_dial_repository.dart';
import '../interfaces/memory_repository.dart';
import '../interfaces/config_repository.dart';
import '../interfaces/text_agent_repository.dart';
import 'json_call_session_repository.dart';
import 'json_speed_dial_repository.dart';
import 'json_memory_repository.dart';
import 'json_config_repository.dart';
import 'preferences_repository.dart';
import 'local_text_agent_repository.dart';
import '../services/log_service.dart';

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
  static TextAgentRepository? _textAgentRepo;
  static LogService? _logService;

  /// Initialize the repositories with a key-value store
  static Future<void> initialize({LogService? logService}) async {
    _logService = logService ?? LogService();
    _store ??= JsonFileStore(
      fileName: 'vagina_config.json',
      folderName: 'VAGINA',
      logService: _logService,
    );
    await _store!.initialize();
  }

  /// Get the CallSession repository
  static CallSessionRepository get callSessions {
    _ensureInitialized();
    return _callSessionRepo ??= JsonCallSessionRepository(_store!, logService: _logService);
  }

  /// Get the SpeedDial repository
  static SpeedDialRepository get speedDials {
    _ensureInitialized();
    return _speedDialRepo ??= JsonSpeedDialRepository(_store!, logService: _logService);
  }

  /// Get the Memory repository
  static MemoryRepository get memory {
    _ensureInitialized();
    return _memoryRepo ??= JsonMemoryRepository(_store!, logService: _logService);
  }

  /// Get the Config repository
  static ConfigRepository get config {
    _ensureInitialized();
    return _configRepo ??= JsonConfigRepository(_store!, logService: _logService);
  }

  /// Get the Preferences repository
  static PreferencesRepository get preferences {
    _ensureInitialized();
    return _preferencesRepo ??= PreferencesRepository(_store!);
  }

  /// Get the TextAgent repository
  static TextAgentRepository get textAgents {
    _ensureInitialized();
    return _textAgentRepo ??= LocalTextAgentRepository(logService: _logService);
  }

  /// Helper to ensure initialization
  static void _ensureInitialized() {
    if (_store == null) {
      throw StateError('RepositoryFactory not initialized. Call initialize() first.');
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
    _textAgentRepo = null;
    _logService = null;
  }
}
