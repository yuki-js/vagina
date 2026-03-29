import 'package:vagina/interfaces/key_value_store.dart';

/// Repository for app preferences and settings
///
/// Note: This repository manages app-level preferences like first launch state.
/// It uses the shared KeyValueStore from RepositoryFactory for consistency
/// with other repositories.
class PreferencesRepository {
  static const String _keyFirstLaunch = 'first_launch_completed';
  static const String _keyPreferredLocaleCode = 'preferred_locale_code';
  static const Set<String> _supportedLocaleCodes = {'ja', 'en'};

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

  /// Returns the persisted locale override language code.
  ///
  /// A `null` value means the app should follow the system locale.
  Future<String?> getPreferredLocaleCode() async {
    final localeCode = await _store.get(_keyPreferredLocaleCode);
    if (localeCode is! String) {
      return null;
    }

    return _supportedLocaleCodes.contains(localeCode) ? localeCode : null;
  }

  /// Persists the locale override language code.
  ///
  /// Passing `null` clears the override and restores system locale behavior.
  Future<void> setPreferredLocaleCode(String? localeCode) async {
    if (localeCode == null) {
      await _store.delete(_keyPreferredLocaleCode);
      return;
    }

    if (!_supportedLocaleCodes.contains(localeCode)) {
      throw ArgumentError.value(
        localeCode,
        'localeCode',
        'Unsupported locale code. Expected one of: ${_supportedLocaleCodes.join(', ')}',
      );
    }

    await _store.set(_keyPreferredLocaleCode, localeCode);
  }

  /// Reset first launch flag (for testing)
  Future<void> resetFirstLaunch() async {
    await _store.delete(_keyFirstLaunch);
  }
}
