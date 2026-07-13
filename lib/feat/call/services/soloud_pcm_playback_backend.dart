import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vagina/feat/call/services/pcm_playback_backend.dart';

/// [PcmPlaybackBackend] implemented by Flutter SoLoud buffer streams.
final class SoloudPcmPlaybackBackend implements PcmPlaybackBackend {
  static Future<void>? _initialization;

  final SoLoud? _injectedSoloud;

  SoLoud? _resolvedSoloud;
  AudioSource? _source;
  SoundHandle? _handle;
  bool _disposed = false;

  SoloudPcmPlaybackBackend({SoLoud? soloud}) : _injectedSoloud = soloud;

  SoLoud get _soloud => _resolvedSoloud ??= _injectedSoloud ?? SoLoud.instance;

  @override
  Future<void> initialize() async {
    _ensureNotDisposed();
    if (_soloud.isInitialized) {
      return;
    }

    final pending = _initialization;
    if (pending != null) {
      await pending;
      return;
    }

    final initialization = _soloud.init(automaticCleanup: false);
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
      rethrow;
    }
  }

  @override
  Future<void> startStream({
    required int sampleRate,
    required int channels,
    required Duration bufferingTime,
  }) async {
    _ensureNotDisposed();
    if (channels != 1) {
      throw ArgumentError.value(
        channels,
        'channels',
        'Only mono PCM is supported',
      );
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
    }
    if (bufferingTime <= Duration.zero) {
      throw ArgumentError.value(
        bufferingTime,
        'bufferingTime',
        'Must be positive',
      );
    }

    await initialize();
    await stopStream();

    final source = _soloud.setBufferStream(
      bufferingType: BufferingType.released,
      bufferingTimeNeeds:
          bufferingTime.inMicroseconds / Duration.microsecondsPerSecond,
      sampleRate: sampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
    );

    try {
      final handle = await _soloud.play(source);
      _source = source;
      _handle = handle;
    } catch (_) {
      await _soloud.disposeSource(source);
      rethrow;
    }
  }

  @override
  Future<void> feed(Uint8List chunk) async {
    _ensureNotDisposed();
    if (chunk.isEmpty) {
      return;
    }

    final source = _source;
    if (source == null) {
      throw StateError('No PCM playback stream is active.');
    }
    _soloud.addAudioDataStream(source, chunk);
  }

  @override
  Future<void> finishStream() async {
    _ensureNotDisposed();
    final source = _source;
    if (source == null) {
      return;
    }

    final finished = source.handles.isEmpty
        ? Future<void>.value()
        : source.allInstancesFinished.first;
    _soloud.setDataIsEnded(source);
    await finished;
    await _disposeActiveSource(source);
  }

  @override
  Future<void> stopStream() async {
    final source = _source;
    final handle = _handle;
    _source = null;
    _handle = null;

    if (source == null || !_soloud.isInitialized) {
      return;
    }

    if (handle != null) {
      await _soloud.stop(handle);
    }
    await _soloud.disposeSource(source);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await stopStream();
    _disposed = true;
  }

  Future<void> _disposeActiveSource(AudioSource source) async {
    if (!identical(_source, source)) {
      return;
    }
    _source = null;
    _handle = null;
    await _soloud.disposeSource(source);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PCM playback backend has already been disposed.');
    }
  }
}
