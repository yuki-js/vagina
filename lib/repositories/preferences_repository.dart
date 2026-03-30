import 'package:vagina/interfaces/key_value_store.dart';

/// Repository for app preferences and settings
///
/// Note: This repository manages app-level preferences like first launch state.
/// It uses the shared KeyValueStore from RepositoryFactory for consistency
/// with other repositories.
class PreferencesRepository {
  static const String _keyFirstLaunch = 'first_launch_completed';
  static const String _keyPreferredLocaleCode = 'preferred_locale_code';
  static const String _keyDismissedAnnouncementTopicIds =
      'dismissed_announcement_topic_ids';
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

  /// Returns the persisted dismissed announcement topic ids.
  Future<Set<String>> getDismissedAnnouncementTopicIds() async {
    final dismissedTopicIds =
        await _store.get(_keyDismissedAnnouncementTopicIds);
    if (dismissedTopicIds is! List) {
      return <String>{};
    }

    return dismissedTopicIds.whereType<String>().toSet();
  }

  /// Persists the full set of dismissed announcement topic ids.
  Future<void> setDismissedAnnouncementTopicIds(
      Iterable<String> topicIds) async {
    final normalizedTopicIds = topicIds
        .map((topicId) => topicId.trim())
        .where((topicId) => topicId.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (normalizedTopicIds.isEmpty) {
      await _store.delete(_keyDismissedAnnouncementTopicIds);
      return;
    }

    await _store.set(_keyDismissedAnnouncementTopicIds, normalizedTopicIds);
  }

  /// Adds a dismissed announcement topic id.
  Future<void> addDismissedAnnouncementTopicId(String topicId) async {
    final normalizedTopicId = topicId.trim();
    if (normalizedTopicId.isEmpty) {
      return;
    }

    final dismissedTopicIds = await getDismissedAnnouncementTopicIds();
    final wasAdded = dismissedTopicIds.add(normalizedTopicId);
    if (!wasAdded) {
      return;
    }

    await setDismissedAnnouncementTopicIds(dismissedTopicIds);
  }

  /// Removes a dismissed announcement topic id.
  Future<void> removeDismissedAnnouncementTopicId(String topicId) async {
    final normalizedTopicId = topicId.trim();
    if (normalizedTopicId.isEmpty) {
      return;
    }

    final dismissedTopicIds = await getDismissedAnnouncementTopicIds();
    final wasRemoved = dismissedTopicIds.remove(normalizedTopicId);
    if (!wasRemoved) {
      return;
    }

    await setDismissedAnnouncementTopicIds(dismissedTopicIds);
  }

  /// Clears all dismissed announcement topic ids.
  Future<void> clearDismissedAnnouncementTopicIds() async {
    await _store.delete(_keyDismissedAnnouncementTopicIds);
  }

  /// Reset first launch flag (for testing)
  Future<void> resetFirstLaunch() async {
    await _store.delete(_keyFirstLaunch);
  }
}
