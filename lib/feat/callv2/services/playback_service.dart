import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:taudio/taudio.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/services/log_service.dart';

/// Lifecycle state for [PlaybackService].
enum PlaybackServiceState {
  uninitialized,
  idle,
  priming,
  playing,
  stopping,
  disposed,
}

/// Immutable snapshot of [PlaybackService] buffering state.
final class PlaybackMetrics {
  final int bufferedBytes;
  final int queuedChunks;
  final bool isInputBound;
  final bool isResponseComplete;

  const PlaybackMetrics({
    required this.bufferedBytes,
    required this.queuedChunks,
    required this.isInputBound,
    required this.isResponseComplete,
  });

  const PlaybackMetrics.idle()
      : bufferedBytes = 0,
        queuedChunks = 0,
        isInputBound = false,
        isResponseComplete = false;

  PlaybackMetrics copyWith({
    int? bufferedBytes,
    int? queuedChunks,
    bool? isInputBound,
    bool? isResponseComplete,
  }) {
    return PlaybackMetrics(
      bufferedBytes: bufferedBytes ?? this.bufferedBytes,
      queuedChunks: queuedChunks ?? this.queuedChunks,
      isInputBound: isInputBound ?? this.isInputBound,
      isResponseComplete: isResponseComplete ?? this.isResponseComplete,
    );
  }
}

/// Session-scoped assistant playback service.
///
/// Owns PCM playback buffering, input-stream binding, and interruption
/// semantics for assistant audio responses.
final class PlaybackService {
  static const _tag = 'PlaybackService';

  final Queue<Uint8List> _bufferQueue = Queue<Uint8List>();
  final StreamController<PlaybackServiceState> _stateController =
      StreamController<PlaybackServiceState>.broadcast();
  final StreamController<PlaybackMetrics> _metricsController =
      StreamController<PlaybackMetrics>.broadcast();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  StreamSubscription<Uint8List>? _inputSubscription;
  Future<void>? _drainFuture;
  PlaybackServiceState _state = PlaybackServiceState.uninitialized;
  PlaybackMetrics _metrics = const PlaybackMetrics.idle();
  int _bufferedBytes = 0;
  int _generation = 0;
  double _volume = 1.0;
  bool _playerOpened = false;
  bool _playerStreaming = false;

  PlaybackService();

  PlaybackServiceState get state => _state;

  bool get isPlaying => _state == PlaybackServiceState.playing;

  int get bufferedBytes => _bufferedBytes;

  Stream<PlaybackServiceState> get states => _stateController.stream;

  Stream<PlaybackMetrics> get metrics => _metricsController.stream;

  Future<void> start() async {
    if (_state == PlaybackServiceState.disposed) {
      throw StateError('PlaybackService has already been disposed.');
    }
    if (_state != PlaybackServiceState.uninitialized) {
      return;
    }

    await _player.openPlayer();
    _playerOpened = true;
    await _player.setVolume(_volume);
    _setState(PlaybackServiceState.idle);
    _emitMetrics();
  }

  Future<void> bindInputStream(Stream<Uint8List> audioStream) async {
    _ensureNotDisposed();
    await start();
    await unbindInputStream();

    _inputSubscription = audioStream.listen(
      (chunk) {
        unawaited(_handleInputChunk(chunk));
      },
      onError: (Object error, StackTrace stackTrace) {},
    );

    _metrics = _metrics.copyWith(isInputBound: true);
    _emitMetrics();
  }

  Future<void> unbindInputStream() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    _metrics = _metrics.copyWith(isInputBound: false);
    _emitMetrics();
  }

  Future<void> markResponseComplete() async {
    _ensureNotDisposed();
    await start();

    if (_bufferQueue.isEmpty && !isPlaying) {
      _metrics = _metrics.copyWith(isResponseComplete: false);
      _emitMetrics();
      return;
    }

    _metrics = _metrics.copyWith(isResponseComplete: true);
    _emitMetrics();
    _ensureDrainLoop();
    await _drainFuture;
  }

  Future<void> interrupt() async {
    _ensureNotDisposed();
    await _resetPlaybackState();
  }

  Future<void> stop() async {
    _ensureNotDisposed();
    await _resetPlaybackState();
  }

  Future<void> setVolume(double volume) async {
    _ensureNotDisposed();
    _volume = volume.clamp(0.0, 1.0);
    await start();
    await _player.setVolume(_volume);
  }

  Future<void> dispose() async {
    if (_state == PlaybackServiceState.disposed) {
      return;
    }

    _generation += 1;
    await unbindInputStream();
    await _drainFuture;
    _drainFuture = null;
    _bufferQueue.clear();
    _bufferedBytes = 0;

    await _stopPlayerIfNeeded();
    if (_playerOpened) {
      await _player.closePlayer();
      _playerOpened = false;
    }

    _state = PlaybackServiceState.disposed;
    await _stateController.close();
    await _metricsController.close();
  }

  Future<void> _handleInputChunk(Uint8List chunk) async {
    if (_state == PlaybackServiceState.disposed || chunk.isEmpty) {
      return;
    }

    await start();

    if (_bufferQueue.isEmpty &&
        (_state == PlaybackServiceState.idle ||
            _state == PlaybackServiceState.priming)) {
      _metrics = _metrics.copyWith(isResponseComplete: false);
    }

    _bufferQueue.add(chunk);
    _bufferedBytes += chunk.length;

    if (_state != PlaybackServiceState.playing) {
      _setState(PlaybackServiceState.priming);
    }

    _emitMetrics();
    _ensureDrainLoop();
  }

  void _ensureDrainLoop() {
    if (_drainFuture != null) {
      return;
    }

    _drainFuture = _drainBufferedAudio(_generation).whenComplete(() {
      _drainFuture = null;
    });
  }

  Future<void> _drainBufferedAudio(int generation) async {
    while (
        generation == _generation && _state != PlaybackServiceState.disposed) {
      if (_bufferQueue.isEmpty) {
        if (_metrics.isResponseComplete) {
          _setState(PlaybackServiceState.idle);
          _metrics = _metrics.copyWith(isResponseComplete: false);
          _emitMetrics();
        }
        return;
      }

      final shouldStartPlayback =
          _bufferedBytes >= AppConfig.minAudioBufferSizeBeforeStart ||
              _metrics.isResponseComplete;
      if (!shouldStartPlayback) {
        _setState(PlaybackServiceState.priming);
        _emitMetrics();
        return;
      }

      if (_state != PlaybackServiceState.playing) {
        await _startPlayerIfNeeded();
        _setState(PlaybackServiceState.playing);
      }

      final chunk = _bufferQueue.removeFirst();
      _bufferedBytes -= chunk.length;
      _emitMetrics();
      await _player.feedUint8FromStream(chunk);
    }
  }

  Future<void> _resetPlaybackState() async {
    await start();

    _generation += 1;
    _setState(PlaybackServiceState.stopping);

    _bufferQueue.clear();
    _bufferedBytes = 0;
    _metrics = _metrics.copyWith(isResponseComplete: false);
    _emitMetrics();

    await _stopPlayerIfNeeded();
    _setState(PlaybackServiceState.idle);
    _emitMetrics();
  }

  Future<void> _startPlayerIfNeeded() async {
    if (_playerStreaming) {
      return;
    }

    _playerStreaming = true;
    try {
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        sampleRate: AppConfig.sampleRate,
        numChannels: AppConfig.channels,
        bufferSize: 8192,
        interleaved: true,
      );
    } catch (_) {
      _playerStreaming = false;
      rethrow;
    }
  }

  Future<void> _stopPlayerIfNeeded() async {
    if (!_playerOpened || !_playerStreaming) {
      return;
    }

    try {
      await _player.stopPlayer();
    } catch (e) {
    } finally {
      _playerStreaming = false;
    }
  }

  void _setState(PlaybackServiceState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _emitMetrics() {
    _metrics = _metrics.copyWith(
      bufferedBytes: _bufferedBytes,
      queuedChunks: _bufferQueue.length,
      isInputBound: _inputSubscription != null,
    );
    if (!_metricsController.isClosed) {
      _metricsController.add(_metrics);
    }
  }

  void _ensureNotDisposed() {
    if (_state == PlaybackServiceState.disposed) {
      throw StateError('PlaybackService has already been disposed.');
    }
  }
}
