import 'package:vagina/interfaces/key_value_store.dart';

/// Repository for app preferences and settings
/// 
/// Note: This repository manages app-level preferences like first launch state.
/// It uses the shared KeyValueStore from RepositoryFactory for consistency
/// with other repositories.
class PreferencesRepository {
  static const String _keyFirstLaunch = 'first_launch_completed';
  
  final KeyValueStore _store;

  PreferencesRepository(this._store);

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
