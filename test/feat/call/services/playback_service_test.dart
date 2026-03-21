// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_player_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:taudio/taudio.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/callv2/services/playback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaybackService', () {
    late FlutterSoundPlayerPlatform originalPlatform;
    late _FakeFlutterSoundPlayerPlatform fakePlatform;
    late PlaybackService service;

    setUp(() {
      originalPlatform = FlutterSoundPlayerPlatform.instance;
      fakePlatform = _FakeFlutterSoundPlayerPlatform();
      FlutterSoundPlayerPlatform.instance = fakePlatform;
      service = PlaybackService();
    });

    tearDown(() async {
      await service.dispose();
      FlutterSoundPlayerPlatform.instance = originalPlatform;
    });

    test(
        'bindInputStream keeps playback in priming state below start threshold',
        () async {
      final controller = StreamController<Uint8List>.broadcast();
      final emittedMetrics = <PlaybackMetrics>[];
      final metricsSubscription = service.metrics.listen(emittedMetrics.add);

      await service.start();
      await service.bindInputStream(controller.stream);

      controller.add(Uint8List.fromList(const <int>[1, 2, 3, 4]));
      await _flushAsyncWork();

      expect(service.state, PlaybackServiceState.priming);
      expect(service.bufferedBytes, 4);
      expect(fakePlatform.startPlayerFromStreamCalls, 0);
      expect(emittedMetrics.last.isInputBound, isTrue);
      expect(emittedMetrics.last.queuedChunks, 1);
      expect(emittedMetrics.last.bufferedBytes, 4);

      await metricsSubscription.cancel();
      await controller.close();
    });

    test('markResponseComplete drains a short response and returns to idle',
        () async {
      final controller = StreamController<Uint8List>.broadcast();
      final emittedMetrics = <PlaybackMetrics>[];
      final metricsSubscription = service.metrics.listen(emittedMetrics.add);
      final chunk = Uint8List.fromList(const <int>[10, 20, 30, 40]);

      await service.start();
      await service.bindInputStream(controller.stream);
      controller.add(chunk);
      await _flushAsyncWork();

      await service.markResponseComplete();
      await _flushAsyncWork();

      expect(fakePlatform.startPlayerFromStreamCalls, 1);
      expect(fakePlatform.feedChunks, hasLength(1));
      expect(fakePlatform.feedChunks.single, orderedEquals(chunk));
      expect(service.state, PlaybackServiceState.idle);
      expect(service.bufferedBytes, 0);
      expect(emittedMetrics.last.isResponseComplete, isFalse);
      expect(emittedMetrics.last.queuedChunks, 0);

      await metricsSubscription.cancel();
      await controller.close();
    });

    test('interrupt clears queued audio and stops active playback', () async {
      final controller = StreamController<Uint8List>.broadcast();
      final chunk = Uint8List(AppConfig.minAudioBufferSizeBeforeStart)
        ..fillRange(0, AppConfig.minAudioBufferSizeBeforeStart, 1);

      await service.start();
      await service.bindInputStream(controller.stream);
      controller.add(chunk);
      await _flushAsyncWork();

      expect(fakePlatform.startPlayerFromStreamCalls, 1);
      expect(fakePlatform.feedChunks, hasLength(1));
      expect(service.state, PlaybackServiceState.playing);

      final stopCallsBeforeInterrupt = fakePlatform.stopPlayerCalls;

      await service.interrupt();
      await _flushAsyncWork();

      expect(service.state, PlaybackServiceState.idle);
      expect(service.bufferedBytes, 0);
      expect(fakePlatform.stopPlayerCalls, stopCallsBeforeInterrupt + 1);

      await controller.close();
    });
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _FakeFlutterSoundPlayerPlatform extends FlutterSoundPlayerPlatform
    with MockPlatformInterfaceMixin {
  final List<Uint8List> feedChunks = <Uint8List>[];
  final List<double> setVolumes = <double>[];

  int initPluginCalls = 0;
  int openPlayerCalls = 0;
  int startPlayerFromStreamCalls = 0;
  int stopPlayerCalls = 0;
  int closePlayerCalls = 0;

  @override
  Future<bool> initPlugin() async {
    initPluginCalls += 1;
    return true;
  }

  @override
  Future<void>? resetPlugin(FlutterSoundPlayerCallback callback) async {}

  @override
  Future<int> openPlayer(
    FlutterSoundPlayerCallback callback, {
    required Level logLevel,
  }) async {
    openPlayerCalls += 1;
    callback.openPlayerCompleted(PlayerState.isStopped.index, true);
    return PlayerState.isStopped.index;
  }

  @override
  Future<int> startPlayerFromStream(
    FlutterSoundPlayerCallback callback, {
    Codec codec = Codec.pcm16,
    bool interleaved = true,
    int numChannels = 1,
    int sampleRate = 16000,
    int bufferSize = 8192,
  }) async {
    startPlayerFromStreamCalls += 1;
    callback.startPlayerCompleted(PlayerState.isPlaying.index, true, 0);
    return PlayerState.isPlaying.index;
  }

  @override
  Future<int> feed(
    FlutterSoundPlayerCallback callback, {
    required Uint8List data,
  }) async {
    feedChunks.add(Uint8List.fromList(data));
    return data.length;
  }

  @override
  Future<int> stopPlayer(FlutterSoundPlayerCallback callback) async {
    stopPlayerCalls += 1;
    callback.stopPlayerCompleted(PlayerState.isStopped.index, true);
    return PlayerState.isStopped.index;
  }

  @override
  Future<int> closePlayer(FlutterSoundPlayerCallback callback) async {
    closePlayerCalls += 1;
    return PlayerState.isStopped.index;
  }

  @override
  Future<int> setVolume(
    FlutterSoundPlayerCallback callback, {
    required double volume,
  }) async {
    setVolumes.add(volume);
    return PlayerState.isStopped.index;
  }
}
