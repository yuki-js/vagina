/// Application configuration
class AppConfig {
  const AppConfig._();

  /// OpenAI Realtime API WebSocket URL
  static const String realtimeApiUrl =
      'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01';

  /// Default assistant voice
  static const String defaultVoice = 'alloy';

  /// Default microphone gain (0.0 to 1.0)
  static const double defaultMicGain = 0.8;

  /// Audio sample rate
  static const int sampleRate = 24000;

  /// Audio channels
  static const int channels = 1;

  /// Audio bit depth
  static const int bitDepth = 16;
}
