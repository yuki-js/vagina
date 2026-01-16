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

  // ==========================================================================
  // Logging Configuration
  // ==========================================================================

  /// Log audio chunks sent/received every N chunks to reduce log noise
  static const int logAudioChunkInterval = 50;

  // ==========================================================================
  // Call Configuration
  // ==========================================================================

  /// Silence timeout in seconds - call will auto-end after this duration of silence
  /// Set to 0 to disable silence detection
  static const int silenceTimeoutSeconds = 180;
}
