import '../data/json_file_store.dart';

/// Repository for app preferences and settings
class PreferencesRepository {
  static const String _fileName = 'app_preferences.json';
  static const String _keyFirstLaunch = 'first_launch_completed';
  
  final JsonFileStore _store;

  PreferencesRepository()
      : _store = JsonFileStore(fileName: _fileName);

  /// Initialize the repository
  Future<void> initialize() async {
    await _store.initialize();
  }

  /// Check if this is the first launch
  Future<bool> isFirstLaunch() async {
    final completed = await _store.get(_keyFirstLaunch);
    return completed != true;
  }

  /// Mark first launch as completed
  Future<void> markFirstLaunchCompleted() async {
    await _store.set(_keyFirstLaunch, true);
  }

  /// Reset first launch flag (for testing)
  Future<void> resetFirstLaunch() async {
    await _store.delete(_keyFirstLaunch);
  }
}
