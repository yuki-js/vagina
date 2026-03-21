// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:vagina/feat/call/services/recorder_service.dart';
import 'package:vagina/utils/audio_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecorderService', () {
    late RecordPlatform originalPlatform;
    late _FakeRecordPlatform fakePlatform;
    late RecorderService service;

    setUp(() {
      originalPlatform = RecordPlatform.instance;
      fakePlatform = _FakeRecordPlatform();
      RecordPlatform.instance = fakePlatform;
      service = RecorderService();
    });

    tearDown(() async {
      await service.dispose();
      RecordPlatform.instance = originalPlatform;
    });

    test('startRecordingSession forwards PCM and reports normalized amplitude',
        () async {
      fakePlatform.currentAmplitude = Amplitude(current: -30.0, max: 0.0);

      final audioFuture = service.audioStream.first;
      final amplitudeFuture = service.amplitudeStream.first;

      await service.startRecordingSession();
      fakePlatform.emitAudio(const <int>[1, 2, 3, 4]);

      final audioChunk = await audioFuture.timeout(const Duration(seconds: 1));
      final amplitude =
          await amplitudeFuture.timeout(const Duration(seconds: 1));

      expect(service.state, RecorderServiceState.recording);
      expect(audioChunk, orderedEquals(const <int>[1, 2, 3, 4]));
      expect(
        amplitude,
        closeTo(AudioUtils.normalizeAmplitude(-30.0), 0.0001),
      );
      expect(fakePlatform.startStreamCalls, 1);
      expect(fakePlatform.hasPermissionCalls, 1);
    });

    test('setMute emits silent PCM and zero amplitude while recorder stays live',
        () async {
      fakePlatform.currentAmplitude = Amplitude(current: -8.0, max: 0.0);

      await service.startRecordingSession();

      final mutedAmplitudeFuture = service.amplitudeStream.first;
      final mutedAudioFuture = service.audioStream.first;

      service.setMute(true);
      fakePlatform.emitAudio(const <int>[9, 8, 7, 6]);

      final mutedAmplitude =
          await mutedAmplitudeFuture.timeout(const Duration(seconds: 1));
      final mutedChunk =
          await mutedAudioFuture.timeout(const Duration(seconds: 1));

      expect(service.isMuted, isTrue);
      expect(service.state, RecorderServiceState.recording);
      expect(mutedAmplitude, 0.0);
      expect(mutedChunk, orderedEquals(const <int>[0, 0, 0, 0]));
      expect(fakePlatform.isRecordingValue, isTrue);
    });

    test('startRecordingSession throws when microphone permission is denied',
        () async {
      fakePlatform.permissionGranted = false;

      await expectLater(
        service.startRecordingSession(),
        throwsA(isA<StateError>()),
      );

      expect(service.state, RecorderServiceState.idle);
      expect(fakePlatform.startStreamCalls, 0);
    });

    test('stopRecordingSession stops active capture and returns to idle',
        () async {
      await service.startRecordingSession();

      await service.stopRecordingSession();

      expect(service.state, RecorderServiceState.idle);
      expect(fakePlatform.stopCalls, 1);
      expect(fakePlatform.isRecordingValue, isFalse);
    });
  });
}

final class _FakeRecordPlatform extends RecordPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<RecordState> _stateController =
      StreamController<RecordState>.broadcast();

  bool permissionGranted = true;
  bool isRecordingValue = false;
  int createCalls = 0;
  int hasPermissionCalls = 0;
  int startStreamCalls = 0;
  int stopCalls = 0;
  Amplitude currentAmplitude = Amplitude(current: -60.0, max: 0.0);

  void emitAudio(List<int> bytes) {
    _audioController.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> create(String recorderId) async {
    createCalls += 1;
  }

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    hasPermissionCalls += 1;
    return permissionGranted;
  }

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> isRecording(String recorderId) async => isRecordingValue;

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<void> start(String recorderId, RecordConfig config,
      {required String path}) async {
    throw UnimplementedError('File recording is not used by RecorderService.');
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    startStreamCalls += 1;
    isRecordingValue = true;
    _stateController.add(RecordState.record);
    return _audioController.stream;
  }

  @override
  Future<String?> stop(String recorderId) async {
    stopCalls += 1;
    isRecordingValue = false;
    _stateController.add(RecordState.stop);
    return null;
  }

  @override
  Future<void> cancel(String recorderId) async {
    isRecordingValue = false;
    _stateController.add(RecordState.stop);
  }

  @override
  Future<void> dispose(String recorderId) async {
    isRecordingValue = false;
    await _audioController.close();
    await _stateController.close();
  }

  @override
  Future<Amplitude> getAmplitude(String recorderId) async => currentAmplitude;

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async {
    return true;
  }

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async {
    return const <InputDevice>[];
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) {
    return _stateController.stream;
  }
}
