/// Application configuration
class AppConfig {
  const AppConfig._();

  /// Azure OpenAI API version
  static const String azureApiVersion = '2024-10-01-preview';

  /// Default assistant voice
  static const String defaultVoice = 'alloy';

  /// Audio sample rate
  static const int sampleRate = 24000;

  /// Audio channels
  static const int channels = 1;

  /// Audio bit depth
  static const int bitDepth = 16;
}
