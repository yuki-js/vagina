/// Utilities for audio processing
class AudioUtils {
  const AudioUtils._();

  /// Minimum dBFS value considered "quiet" (silence threshold)
  static const double dbfsQuietThreshold = -60.0;

  /// Range of dBFS values for normalization
  static const double dbfsRange = 60.0;

  /// Normalize a dBFS amplitude value to 0.0-1.0 range
  ///
  /// [dbfs] - The amplitude in dBFS (typically -60.0 to 0.0)
  /// Returns a normalized value between 0.0 and 1.0
  static double normalizeAmplitude(double dbfs) {
    return ((dbfs - dbfsQuietThreshold) / dbfsRange).clamp(0.0, 1.0);
  }
}
