import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:taudio/taudio.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/call/services/subservice.dart';

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
final class PlaybackService extends SubService {
  /// Buffer size for audio playback streaming
  static const int playbackBufferSize = 8192;
  static const Duration drainCancellationTimeout = Duration(milliseconds: 100);

  final Queue<Uint8List> _bufferQueue = Queue<Uint8List>();
  final StreamController<bool> _playingStateController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _muteStateController =
      StreamController<bool>.broadcast();
  final StreamController<PlaybackMetrics> _metricsController =
      StreamController<PlaybackMetrics>.broadcast();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  StreamSubscription<Uint8List>? _inputSubscription;
  Future<void>? _drainFuture;
  bool _isPlaying = false;
  bool _isMuted = false;
  PlaybackMetrics _metrics = const PlaybackMetrics.idle();
  int _bufferedBytes = 0;
  int _generation = 0;
  bool _playerOpened = false;
  bool _playerStreaming = false;

  PlaybackService();

  bool get isPlaying => _isPlaying;

  bool get isMuted => _isMuted;

  int get bufferedBytes => _bufferedBytes;

  Stream<bool> get playingStates => _playingStateController.stream;

  Stream<bool> get muteState => _muteStateController.stream;

  Stream<PlaybackMetrics> get metrics => _metricsController.stream;

  @override
  Future<void> start() async {
    await super.start();

    if (_playerOpened) {
      return;
    }

    await _player.openPlayer();
    _playerOpened = true;
    _emitMetrics();
  }

  Future<void> bindInputStream(Stream<Uint8List> audioStream) async {
    ensureNotDisposed();
    await start();
    await unbindInputStream();

    _inputSubscription = audioStream.listen(
      (chunk) {
        unawaited(_handleInputChunk(chunk));
      },
      onError: (Object error, StackTrace stackTrace) {
        logger.severe('Input stream error', error, stackTrace);
      },
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
    ensureNotDisposed();
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
    ensureNotDisposed();
    await _resetPlaybackState(waitForDrain: false);
  }

  Future<void> stop() async {
    ensureNotDisposed();
    await _resetPlaybackState(waitForDrain: false);
  }

  Future<void> setMute(bool muted) async {
    ensureNotDisposed();
    if (_isMuted == muted) {
      return;
    }

    _isMuted = muted;

    if (!_muteStateController.isClosed) {
      _muteStateController.add(_isMuted);
    }

    if (_isMuted) {
      await _resetPlaybackState();
    }
  }

  @override
  Future<void> dispose() async {
    await super.dispose();

    _generation += 1;
    await unbindInputStream();
    final pendingDrain = _drainFuture;
    _drainFuture = null;
    if (pendingDrain != null) {
      await pendingDrain.timeout(
        drainCancellationTimeout,
        onTimeout: () {
          logger.warning('Timed out waiting for drain loop during dispose');
        },
      );
    }
    _bufferQueue.clear();
    _bufferedBytes = 0;

    await _stopPlayerIfNeeded();
    if (_playerOpened) {
      await _player.closePlayer();
      _playerOpened = false;
    }

    await _playingStateController.close();
    await _muteStateController.close();
    await _metricsController.close();
  }

  Future<void> _handleInputChunk(Uint8List chunk) async {
    if (isDisposed || chunk.isEmpty) {
      return;
    }

    await start();

    if (_isMuted) {
      return;
    }

    if (_bufferQueue.isEmpty && !_isPlaying) {
      _metrics = _metrics.copyWith(isResponseComplete: false);
    }

    _bufferQueue.add(chunk);
    _bufferedBytes += chunk.length;
    _emitMetrics();
    _ensureDrainLoop();
  }

  void _ensureDrainLoop() {
    if (_isMuted || _drainFuture != null) {
      return;
    }

    late final Future<void> drainFuture;
    drainFuture = _drainBufferedAudio(_generation).whenComplete(() {
      if (identical(_drainFuture, drainFuture)) {
        _drainFuture = null;
      }
    });
    _drainFuture = drainFuture;
  }

  Future<void> _drainBufferedAudio(int generation) async {
    while (generation == _generation && !isDisposed && !_isMuted) {
      if (_bufferQueue.isEmpty) {
        if (_metrics.isResponseComplete) {
          _setPlayingState(false);
          _metrics = _metrics.copyWith(isResponseComplete: false);
          _emitMetrics();
        }
        return;
      }

      final shouldStartPlayback =
          _bufferedBytes >= AppConfig.minAudioBufferSizeBeforeStart ||
              _metrics.isResponseComplete;
      if (!shouldStartPlayback) {
        _emitMetrics();
        return;
      }

      if (!_isPlaying) {
        await _startPlayerIfNeeded();
        if (generation != _generation || isDisposed || _isMuted) {
          return;
        }
        _setPlayingState(true);
      }

      if (generation != _generation || isDisposed || _isMuted) {
        return;
      }

      final chunk = _bufferQueue.removeFirst();
      _bufferedBytes -= chunk.length;
      _emitMetrics();
      await _player.feedUint8FromStream(chunk);
    }
  }

  Future<void> _resetPlaybackState({bool waitForDrain = false}) async {
    await start();

    final pendingDrain = _drainFuture;
    _generation += 1;
    _drainFuture = null;

    _bufferQueue.clear();
    _bufferedBytes = 0;
    _metrics = _metrics.copyWith(isResponseComplete: false);
    _emitMetrics();

    await _stopPlayerIfNeeded();
    _setPlayingState(false);
    _emitMetrics();

    if (waitForDrain && pendingDrain != null) {
      await pendingDrain.timeout(
        drainCancellationTimeout,
        onTimeout: () {
          logger.warning('Timed out waiting for drain loop reset');
        },
      );
    }
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
        bufferSize: playbackBufferSize,
        interleaved: true,
      );
    } catch (e, stackTrace) {
      logger.severe('Failed to start audio player', e, stackTrace);
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
    } catch (e, stackTrace) {
      logger.warning('Error stopping audio player', e, stackTrace);
    } finally {
      _playerStreaming = false;
    }
  }

  void _setPlayingState(bool isPlaying) {
    if (_isPlaying == isPlaying) {
      return;
    }
    _isPlaying = isPlaying;
    if (!_playingStateController.isClosed) {
      _playingStateController.add(_isPlaying);
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
}
