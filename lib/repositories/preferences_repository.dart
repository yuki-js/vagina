import 'package:vagina/core/config/app_config.dart';
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
  static const String _keyPreferredCallPushToTalkEnabled =
      'preferred_call_push_to_talk_enabled';
  static const String _keyPreferredCallIdleDisconnectTimeoutSeconds =
      'preferred_call_idle_disconnect_timeout_seconds';
  static const String _keyAuthRefreshToken = 'auth_refresh_token';
  static const String _keyLegacyAuthSession = 'auth_session';
  static const String _keyPendingPkceVerifier = 'pending_pkce_verifier';
  static const String _keyPendingOidcProvider = 'pending_oidc_provider';
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
    final dismissedTopicIds = await _store.get(
      _keyDismissedAnnouncementTopicIds,
    );
    if (dismissedTopicIds is! List) {
      return <String>{};
    }

    return dismissedTopicIds.whereType<String>().toSet();
  }

  /// Persists the full set of dismissed announcement topic ids.
  Future<void> setDismissedAnnouncementTopicIds(
    Iterable<String> topicIds,
  ) async {
    final normalizedTopicIds =
        topicIds
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

  /// Returns whether push-to-talk should be the default call talk mode.
  ///
  /// A missing or invalid value falls back to hands-free.
  Future<bool> getPreferredCallPushToTalkEnabled() async {
    final enabled = await _store.get(_keyPreferredCallPushToTalkEnabled);
    return enabled == true;
  }

  /// Persists the app-wide default call talk mode.
  Future<void> setPreferredCallPushToTalkEnabled(bool enabled) async {
    await _store.set(_keyPreferredCallPushToTalkEnabled, enabled);
  }

  /// Returns the persisted idle disconnect timeout in seconds.
  ///
  /// A missing or unsupported value falls back to the default 3 minutes.
  Future<int> getPreferredCallIdleDisconnectTimeoutSeconds() async {
    final timeoutSeconds = await _store.get(
      _keyPreferredCallIdleDisconnectTimeoutSeconds,
    );
    if (timeoutSeconds is! int) {
      return AppConfig.defaultSilenceTimeoutSeconds;
    }

    if (!AppConfig.silenceTimeoutSecondsOptions.contains(timeoutSeconds)) {
      return AppConfig.defaultSilenceTimeoutSeconds;
    }

    return timeoutSeconds;
  }

  /// Persists the app-wide idle disconnect timeout in seconds.
  Future<void> setPreferredCallIdleDisconnectTimeoutSeconds(
    int timeoutSeconds,
  ) async {
    if (!AppConfig.silenceTimeoutSecondsOptions.contains(timeoutSeconds)) {
      throw ArgumentError.value(
        timeoutSeconds,
        'timeoutSeconds',
        'Unsupported idle disconnect timeout. Expected one of: ${AppConfig.silenceTimeoutSecondsOptions.join(', ')}',
      );
    }

    await _store.set(
      _keyPreferredCallIdleDisconnectTimeoutSeconds,
      timeoutSeconds,
    );
  }

  /// Returns the persisted authentication refresh token, if present.
  Future<String?> getAuthRefreshToken() async {
    await _migrateLegacyAuthSessionIfNeeded();
    final token = await _store.get(_keyAuthRefreshToken);
    if (token is! String) {
      return null;
    }

    final normalized = token.trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// Persists the authentication refresh token.
  Future<void> saveAuthRefreshToken(String refreshToken) async {
    final normalized = refreshToken.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        refreshToken,
        'refreshToken',
        'Refresh token must not be empty.',
      );
    }
    await _store.set(_keyAuthRefreshToken, normalized);
  }

  /// Removes persisted authentication refresh token.
  Future<void> clearAuthRefreshToken() async {
    await _store.delete(_keyAuthRefreshToken);
    await _store.delete(_keyLegacyAuthSession);
  }

  Future<void> savePendingPkceVerifier(String codeVerifier) async {
    final normalized = codeVerifier.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        codeVerifier,
        'codeVerifier',
        'codeVerifier must not be empty.',
      );
    }
    await _store.set(_keyPendingPkceVerifier, normalized);
  }

  Future<String?> consumePendingPkceVerifier() async {
    final raw = await _store.get(_keyPendingPkceVerifier);
    await _store.delete(_keyPendingPkceVerifier);
    if (raw is! String) {
      return null;
    }
    final normalized = raw.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> clearPendingPkceVerifier() async {
    await _store.delete(_keyPendingPkceVerifier);
  }

  Future<void> savePendingOidcProvider(String provider) async {
    final normalized = provider.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        provider,
        'provider',
        'provider must not be empty.',
      );
    }
    await _store.set(_keyPendingOidcProvider, normalized);
  }

  Future<String?> consumePendingOidcProvider() async {
    final raw = await _store.get(_keyPendingOidcProvider);
    await _store.delete(_keyPendingOidcProvider);
    if (raw is! String) {
      return null;
    }
    final normalized = raw.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> clearPendingOidcProvider() async {
    await _store.delete(_keyPendingOidcProvider);
  }

  Future<void> _migrateLegacyAuthSessionIfNeeded() async {
    final hasRefreshToken = await _store.contains(_keyAuthRefreshToken);
    if (hasRefreshToken) {
      if (await _store.contains(_keyLegacyAuthSession)) {
        await _store.delete(_keyLegacyAuthSession);
      }
      return;
    }

    final raw = await _store.get(_keyLegacyAuthSession);
    if (raw is Map) {
      final token = raw['refreshToken'];
      if (token is String && token.trim().isNotEmpty) {
        await _store.set(_keyAuthRefreshToken, token.trim());
      }
    }

    if (await _store.contains(_keyLegacyAuthSession)) {
      await _store.delete(_keyLegacyAuthSession);
    }
  }

  /// Reset first launch flag (for testing)
  Future<void> resetFirstLaunch() async {
    await _store.delete(_keyFirstLaunch);
  }
}
