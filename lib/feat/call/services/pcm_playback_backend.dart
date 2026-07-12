import 'dart:typed_data';

/// Native playback boundary for a single live PCM response stream.
abstract interface class PcmPlaybackBackend {
  /// Prepares the underlying audio engine.
  Future<void> initialize();

  /// Starts a new signed 16-bit little-endian PCM stream.
  Future<void> startStream({
    required int sampleRate,
    required int channels,
    required Duration bufferingTime,
  });

  /// Appends PCM bytes to the active stream in arrival order.
  Future<void> feed(Uint8List chunk);

  /// Marks the active stream complete and waits until buffered audio finishes.
  Future<void> finishStream();

  /// Immediately stops and discards the active stream.
  Future<void> stopStream();

  /// Releases resources owned by this backend.
  Future<void> dispose();
}
