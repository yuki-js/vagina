import 'package:flutter/foundation.dart';

/// Application configuration
///
/// Contains all application-wide configuration constants.
/// Audio-related constants should be kept in sync with Azure OpenAI
/// Realtime API requirements (24kHz, 16-bit, mono PCM).
class AppConfig {
  const AppConfig._();

  // ==========================================================================
  // Application Identity
  // ==========================================================================

  /// Application display name (shown in UI)
  /// Note: Codename "vagina" is used throughout codebase but display name
  /// can be different for branding purposes
  static const String appName = 'VAGINA';

  /// Application subtitle/tagline
  static const String appSubtitle = 'Voice AGI Notepad Agent';

  /// Remote JSON endpoint for app announcements.
  ///
  /// Configure with either an absolute URL or a Flutter Web-served relative
  /// path:
  /// `flutter run --dart-define=ANNOUNCEMENT_JSON_URL=https://example.com/announcements.json`
  /// `flutter run -d chrome --dart-define=ANNOUNCEMENT_JSON_URL=assets/announcements/dev.json`
  ///
  /// When no explicit override is provided, Flutter Web debug builds fall back
  /// to the local dev fixture for announcement previewing.
  static const String announcementJsonUrl = String.fromEnvironment(
      'ANNOUNCEMENT_JSON_URL',
      defaultValue: 'https://vagina.app/announcement.json');

  /// Default asset path for local announcement preview fixtures.
  static const String devAnnouncementJsonAssetPath =
      'assets/announcements/dev.json';

  /// Parsed announcement endpoint URI, or `null` when not configured.
  static Uri? get announcementJsonUri {
    return resolveAnnouncementJsonUri(
      resolveAnnouncementJsonUrl(
        announcementJsonUrl,
        isWeb: kIsWeb,
        isDebugMode: kDebugMode,
      ),
    );
  }

  /// Resolves the configured announcement endpoint string.
  ///
  /// Explicit environment overrides always win. Otherwise, Flutter Web debug
  /// builds default to the local dev fixture.
  static String resolveAnnouncementJsonUrl(
    String rawUrl, {
    required bool isWeb,
    required bool isDebugMode,
  }) {
    final trimmedUrl = rawUrl.trim();
    if (trimmedUrl.isNotEmpty) {
      return trimmedUrl;
    }

    if (isWeb && isDebugMode) {
      return devAnnouncementJsonAssetPath;
    }

    return '';
  }

  /// Resolves an announcement endpoint into a fetchable URI.
  ///
  /// Relative paths are resolved against `Uri.base`, which allows Flutter Web
  /// dev builds to fetch announcement fixtures served from local assets.
  static Uri? resolveAnnouncementJsonUri(String rawUrl) {
    final trimmedUrl = rawUrl.trim();
    if (trimmedUrl.isEmpty) {
      return null;
    }

    final parsedUri = Uri.parse(trimmedUrl);
    if (parsedUri.hasScheme || parsedUri.host.isNotEmpty) {
      return parsedUri;
    }

    return Uri.base.resolveUri(parsedUri);
  }

  /// Azure OpenAI API version
  static const String azureApiVersion = '2024-10-01-preview';

  /// Default assistant voice
  static const String defaultVoice = 'alloy';

  // ==========================================================================
  // Audio Configuration
  // ==========================================================================

  /// Audio sample rate (Hz) - Azure OpenAI Realtime API uses 24kHz
  static const int sampleRate = 24000;

  /// Audio channels - Azure OpenAI Realtime API uses mono
  static const int channels = 1;

  /// Audio bit depth - Azure OpenAI Realtime API uses 16-bit PCM
  static const int bitDepth = 16;

  /// Minimum audio buffer size (bytes) before starting playback
  /// This prevents choppy playback by buffering enough data first.
  /// Value: 4800 bytes = 100ms of audio at 24kHz mono 16-bit
  static const int minAudioBufferSizeBeforeStart = 4800;

  /// Minimum captured duration required for a PTT turn to be committed.
  static const Duration minPttAudioDuration = Duration(milliseconds: 500);

  /// Delay before finalizing a PTT release so brief chatter can be absorbed.
  static const Duration pttReleaseDebounce = Duration(milliseconds: 200);

  // ==========================================================================
  // Logging Configuration
  // ==========================================================================

  /// Log audio chunks sent/received every N chunks to reduce log noise
  static const int logAudioChunkInterval = 250;

  // ==========================================================================
  // Call Configuration
  // ==========================================================================

  /// Silence timeout in seconds - call will auto-end after this duration of silence
  /// Set to 0 to disable silence detection
  static const int silenceTimeoutSeconds = 180;
}
