import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/services/pcm_playback_backend.dart';
import 'package:vagina/feat/call/services/playback_service.dart';

void main() {
  group('PlaybackService', () {
    late FakePcmPlaybackBackend backend;
    late PlaybackService service;
    late StreamController<Uint8List> input;

    setUp(() async {
      backend = FakePcmPlaybackBackend();
      service = PlaybackService(backend: backend);
      input = StreamController<Uint8List>();
      await service.bindInputStream(input.stream);
    });

    tearDown(() async {
      await input.close();
      if (!service.isDisposed) {
        await service.dispose();
      }
    });

    test('initializes the backend once', () async {
      await service.start();
      await service.start();

      expect(backend.initializeCalls, 1);
    });

    test('waits for 4800 buffered bytes before starting playback', () async {
      input.add(Uint8List(4799));
      await _waitUntil(() => service.bufferedBytes == 4799);

      expect(backend.startCalls, 0);

      input.add(Uint8List(1));
      await _waitUntil(() => backend.startCalls == 1);

      expect(backend.sampleRate, 24000);
      expect(backend.channels, 1);
      expect(backend.bufferingTime, const Duration(milliseconds: 100));
    });

    test('starts and drains a completed short response', () async {
      input.add(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await _waitUntil(() => service.bufferedBytes == 4);

      await service.markResponseComplete();

      expect(backend.startCalls, 1);
      expect(backend.fedChunks.single, <int>[1, 2, 3, 4]);
      expect(backend.finishCalls, 1);
      expect(service.isPlaying, isFalse);
      expect(service.bufferedBytes, 0);
    });

    test('feeds chunks in arrival order', () async {
      final first = _filledBytes(4800, 1);
      final second = Uint8List.fromList(<int>[2, 3]);
      input
        ..add(first)
        ..add(second);

      await _waitUntil(() => backend.fedChunks.length == 2);
      await service.markResponseComplete();

      expect(backend.fedChunks[0], first);
      expect(backend.fedChunks[1], second);
    });

    test('waits for native buffered audio before becoming idle', () async {
      backend.completeFinishAutomatically = false;
      input.add(_filledBytes(4800, 1));
      await _waitUntil(() => backend.fedChunks.isNotEmpty);

      var completed = false;
      final completion = service.markResponseComplete().then((_) {
        completed = true;
      });
      await _waitUntil(() => backend.finishCalls == 1);

      expect(completed, isFalse);
      expect(service.isPlaying, isTrue);

      backend.completeFinish();
      await completion;

      expect(service.isPlaying, isFalse);
    });

    test('interrupt clears queued and native audio', () async {
      input.add(_filledBytes(4800, 1));
      await _waitUntil(() => backend.fedChunks.isNotEmpty);

      await service.interrupt();

      expect(backend.stopCalls, 1);
      expect(service.bufferedBytes, 0);
      expect(service.isPlaying, isFalse);
    });

    test('mute interrupts playback and ignores audio until unmuted', () async {
      input.add(_filledBytes(4800, 1));
      await _waitUntil(() => backend.fedChunks.isNotEmpty);

      await service.setMute(true);
      input.add(_filledBytes(4800, 2));
      await Future<void>.delayed(Duration.zero);

      expect(backend.stopCalls, 1);
      expect(backend.startCalls, 1);

      await service.setMute(false);
      input.add(_filledBytes(4800, 3));
      await _waitUntil(() => backend.startCalls == 2);
    });

    test('a response after interruption uses a fresh native stream', () async {
      input.add(_filledBytes(4800, 1));
      await _waitUntil(() => backend.startCalls == 1);
      await service.interrupt();

      input.add(_filledBytes(4800, 2));
      await _waitUntil(() => backend.startCalls == 2);
      await service.markResponseComplete();

      expect(backend.stopCalls, 1);
      expect(backend.finishCalls, 1);
    });

    test('propagates native stream startup errors', () async {
      backend.startError = StateError('audio device unavailable');
      input.add(Uint8List.fromList(<int>[1, 2, 3, 4]));
      await _waitUntil(() => service.bufferedBytes == 4);

      await expectLater(
        service.markResponseComplete(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'audio device unavailable',
          ),
        ),
      );

      expect(service.isPlaying, isFalse);
    });

    test('dispose stops active playback and disposes backend once', () async {
      input.add(_filledBytes(4800, 1));
      await _waitUntil(() => backend.startCalls == 1);

      await service.dispose();
      await service.dispose();

      expect(backend.stopCalls, 1);
      expect(backend.disposeCalls, 1);
    });
  });
}

Uint8List _filledBytes(int length, int value) {
  return Uint8List.fromList(List<int>.filled(length, value));
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Condition was not met before timeout.');
}

final class FakePcmPlaybackBackend implements PcmPlaybackBackend {
  int initializeCalls = 0;
  int startCalls = 0;
  int finishCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  int? sampleRate;
  int? channels;
  Duration? bufferingTime;
  bool completeFinishAutomatically = true;
  Object? startError;
  final List<Uint8List> fedChunks = <Uint8List>[];

  Completer<void>? _finishCompleter;
  bool _streamActive = false;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<void> startStream({
    required int sampleRate,
    required int channels,
    required Duration bufferingTime,
  }) async {
    startCalls += 1;
    final error = startError;
    if (error != null) {
      throw error;
    }
    this.sampleRate = sampleRate;
    this.channels = channels;
    this.bufferingTime = bufferingTime;
    _streamActive = true;
  }

  @override
  Future<void> feed(Uint8List chunk) async {
    if (!_streamActive) {
      throw StateError('No fake stream is active.');
    }
    fedChunks.add(Uint8List.fromList(chunk));
  }

  @override
  Future<void> finishStream() async {
    finishCalls += 1;
    if (!completeFinishAutomatically) {
      _finishCompleter = Completer<void>();
      await _finishCompleter!.future;
    }
    _streamActive = false;
  }

  void completeFinish() {
    _finishCompleter?.complete();
  }

  @override
  Future<void> stopStream() async {
    if (!_streamActive) {
      return;
    }
    stopCalls += 1;
    _streamActive = false;
    if (!(_finishCompleter?.isCompleted ?? true)) {
      _finishCompleter!.complete();
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await stopStream();
  }
}
