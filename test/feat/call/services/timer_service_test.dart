import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/services/timer_service.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/virtual_filesystem_repository.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/virtual_file.dart';

class _MockCallService extends CallService {
  int endCallCount = 0;
  String? lastEndContext;
  final StreamController<CallState> _mockStateController =
      StreamController<CallState>.broadcast();

  _MockCallService({
    required super.filesystemRepository,
    required super.sessionRepository,
  });

  @override
  Stream<CallState> get states => _mockStateController.stream;

  void mockStateChange(CallState newState) {
    _mockStateController.add(newState);
  }

  @override
  Future<void> endCall({String? endContext}) async {
    endCallCount++;
    lastEndContext = endContext;
  }

  Future<void> disposeMock() async {
    await _mockStateController.close();
  }
}

class _MockVirtualFilesystemRepository implements VirtualFilesystemRepository {
  @override
  Future<void> initialize() async {}

  @override
  Future<VirtualFile?> read(String path) async => null;

  @override
  Future<void> write(VirtualFile file) async {}

  @override
  Future<void> delete(String path) async {}

  @override
  Future<void> move(String fromPath, String toPath) async {}

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async => [];
}

class _MockCallSessionRepository implements CallSessionRepository {
  @override
  Future<void> save(CallSession session) async {}

  @override
  Future<List<CallSession>> getAll() async => [];

  @override
  Future<CallSession?> getById(String id) async => null;

  @override
  Future<bool> delete(String id) async => true;

  @override
  Future<void> deleteAll() async {}
}

void main() {
  group('TimerService', () {
    late TimerService service;
    late _MockCallService mockCallService;

    setUp(() {
      mockCallService = _MockCallService(
        filesystemRepository: _MockVirtualFilesystemRepository(),
        sessionRepository: _MockCallSessionRepository(),
      );
      service = TimerService(mockCallService);
    });

    tearDown(() async {
      await service.dispose();
      await mockCallService.disposeMock();
    });

    group('Lifecycle', () {
      test('initial state is uninitialized', () {
        expect(service.state, TimerServiceState.uninitialized);
      });

      test('start() transitions to idle state', () async {
        await service.start();
        expect(service.state, TimerServiceState.idle);
      });

      test('start() is idempotent', () async {
        await service.start();
        await service.start();
        expect(service.state, TimerServiceState.idle);
      });

      test('dispose() transitions to disposed state', () async {
        await service.start();
        await service.dispose();
        expect(service.state, TimerServiceState.disposed);
      });

      test('dispose() is idempotent', () async {
        await service.start();
        await service.dispose();
        await service.dispose();
        expect(service.state, TimerServiceState.disposed);
      });

      test('operations throw after dispose', () async {
        await service.start();
        await service.dispose();

        expect(() => service.startTracking(), throwsStateError);
        expect(() => service.stopTracking(), throwsStateError);
        expect(() => service.resetSilenceTimer(), throwsStateError);
        expect(() => service.setSilenceTimeout(Duration(seconds: 60)), throwsStateError);
      });
    });

    group('Auto-start on CallState change', () {
      test('automatically starts tracking when CallService becomes active', () async {
        await service.start();
        expect(service.state, TimerServiceState.idle);

        mockCallService.mockStateChange(CallState.active);
        await Future.delayed(Duration(milliseconds: 100));

        expect(service.state, TimerServiceState.tracking);
      });

      test('automatically stops tracking when CallService starts disposing', () async {
        await service.start();
        service.startTracking();
        expect(service.state, TimerServiceState.tracking);

        mockCallService.mockStateChange(CallState.disposing);
        await Future.delayed(Duration(milliseconds: 100));

        expect(service.state, TimerServiceState.idle);
      });
    });

    group('Duration Tracking', () {
      test('startTracking() transitions to tracking state', () async {
        await service.start();
        service.startTracking();
        expect(service.state, TimerServiceState.tracking);
      });

      test('startTracking() initializes startedAt timestamp', () async {
        await service.start();
        expect(service.startedAt, isNull);
        
        service.startTracking();
        expect(service.startedAt, isNotNull);
      });

      test('startTracking() initializes elapsed to near zero', () async {
        await service.start();
        service.startTracking();
        expect(service.elapsed.inMilliseconds, lessThan(10));
      });

      test('startTracking() is idempotent', () async {
        await service.start();
        service.startTracking();
        final firstStartedAt = service.startedAt;
        
        await Future.delayed(Duration(milliseconds: 100));
        service.startTracking();
        
        expect(service.startedAt, firstStartedAt);
        expect(service.state, TimerServiceState.tracking);
      });

      test('durationUpdates emits elapsed time every second', () async {
        await service.start();
        
        final durations = <Duration>[];
        final subscription = service.durationUpdates.listen(durations.add);
        
        service.startTracking();
        
        await Future.delayed(Duration(milliseconds: 2500));
        
        await subscription.cancel();
        
        expect(durations.length, greaterThanOrEqualTo(2));
        expect(durations.first.inSeconds, greaterThanOrEqualTo(1));
        expect(durations.last.inSeconds, greaterThanOrEqualTo(2));
      });

      test('elapsed increases over time when tracking', () async {
        await service.start();
        service.startTracking();
        
        await Future.delayed(Duration(milliseconds: 100));
        final elapsed1 = service.elapsed;
        expect(elapsed1.inMilliseconds, greaterThanOrEqualTo(100));
        
        await Future.delayed(Duration(milliseconds: 100));
        final elapsed2 = service.elapsed;
        expect(elapsed2.inMilliseconds, greaterThan(elapsed1.inMilliseconds));
      });

      test('stopTracking() transitions to idle state', () async {
        await service.start();
        service.startTracking();
        service.stopTracking();
        expect(service.state, TimerServiceState.idle);
      });

      test('stopTracking() stops duration updates', () async {
        await service.start();
        
        final durations = <Duration>[];
        final subscription = service.durationUpdates.listen(durations.add);
        
        service.startTracking();
        await Future.delayed(Duration(milliseconds: 1500));
        service.stopTracking();
        
        final countAfterStop = durations.length;
        await Future.delayed(Duration(milliseconds: 1500));
        
        await subscription.cancel();
        
        expect(durations.length, countAfterStop);
      });

      test('stopTracking() is safe when not tracking', () async {
        await service.start();
        service.stopTracking(); // Should not throw
        expect(service.state, TimerServiceState.idle);
      });
    });

    group('Silence Timeout', () {
      test('default silence timeout is 180 seconds', () {
        expect(service.silenceTimeout, Duration(seconds: 180));
      });

      test('can configure silence timeout in constructor', () {
        final customService = TimerService(
          mockCallService,
          silenceTimeout: Duration(seconds: 60),
        );
        expect(customService.silenceTimeout, Duration(seconds: 60));
        customService.dispose();
      });

      test('setSilenceTimeout() updates timeout duration', () async {
        await service.start();
        service.setSilenceTimeout(Duration(seconds: 120));
        expect(service.silenceTimeout, Duration(seconds: 120));
      });

      test('timeoutEvents emits when silence timeout occurs', () async {
        final shortTimeoutService = TimerService(
          mockCallService,
          silenceTimeout: Duration(milliseconds: 500),
        );
        await shortTimeoutService.start();
        
        final timeoutEvents = <void>[];
        final subscription = shortTimeoutService.timeoutEvents.listen(
          (_) => timeoutEvents.add(null),
        );
        
        shortTimeoutService.startTracking();
        
        await Future.delayed(Duration(milliseconds: 1600));
        
        await subscription.cancel();
        await shortTimeoutService.dispose();
        
        expect(timeoutEvents.length, greaterThanOrEqualTo(1));
      });

      test('calls endCall on CallService when timeout occurs', () async {
        final shortTimeoutService = TimerService(
          mockCallService,
          silenceTimeout: Duration(milliseconds: 500),
        );
        await shortTimeoutService.start();
        
        shortTimeoutService.startTracking();
        
        expect(mockCallService.endCallCount, 0);
        
        await Future.delayed(Duration(milliseconds: 1600));
        
        await shortTimeoutService.dispose();
        
        expect(mockCallService.endCallCount, greaterThanOrEqualTo(1));
        expect(mockCallService.lastEndContext, 'silence_timeout');
      });

      test('resetSilenceTimer() delays timeout', () async {
        final shortTimeoutService = TimerService(
          mockCallService,
          silenceTimeout: Duration(seconds: 2),
        );
        await shortTimeoutService.start();
        
        final timeoutEvents = <void>[];
        final subscription = shortTimeoutService.timeoutEvents.listen(
          (_) => timeoutEvents.add(null),
        );
        
        shortTimeoutService.startTracking();
        
        await Future.delayed(Duration(milliseconds: 1500));
        shortTimeoutService.resetSilenceTimer();
        
        await Future.delayed(Duration(milliseconds: 1500));
        expect(timeoutEvents.length, 0); // Should not have timed out yet (reset happened)
        
        await Future.delayed(Duration(milliseconds: 1500));
        expect(timeoutEvents.length, greaterThanOrEqualTo(1)); // Now should have timed out
        
        await subscription.cancel();
        await shortTimeoutService.dispose();
      });

      test('resetSilenceTimer() is safe when not tracking', () async {
        await service.start();
        service.resetSilenceTimer(); // Should not throw
        expect(service.state, TimerServiceState.idle);
      });

      test('stopTracking() cancels silence timer', () async {
        final shortTimeoutService = TimerService(
          mockCallService,
          silenceTimeout: Duration(milliseconds: 500),
        );
        await shortTimeoutService.start();
        
        final timeoutEvents = <void>[];
        final subscription = shortTimeoutService.timeoutEvents.listen(
          (_) => timeoutEvents.add(null),
        );
        
        shortTimeoutService.startTracking();
        await Future.delayed(Duration(milliseconds: 300));
        shortTimeoutService.stopTracking();
        
        await Future.delayed(Duration(milliseconds: 300));
        
        await subscription.cancel();
        await shortTimeoutService.dispose();
        
        expect(timeoutEvents.length, 0);
        expect(mockCallService.endCallCount, 0);
      });

      test('setSilenceTimeout() takes effect immediately', () async {
        final shortTimeoutService = TimerService(
          mockCallService,
          silenceTimeout: Duration(seconds: 5),
        );
        await shortTimeoutService.start();
        
        final timeoutEvents = <void>[];
        final subscription = shortTimeoutService.timeoutEvents.listen(
          (_) => timeoutEvents.add(null),
        );
        
        shortTimeoutService.startTracking();
        
        // Reset activity to start fresh
        shortTimeoutService.resetSilenceTimer();
        
        await Future.delayed(Duration(milliseconds: 100));
        shortTimeoutService.setSilenceTimeout(Duration(seconds: 2));
        
        await Future.delayed(Duration(milliseconds: 1500));
        expect(timeoutEvents.length, 0); // Not yet (1600ms < 2s)
        
        await Future.delayed(Duration(milliseconds: 1000));
        expect(timeoutEvents.length, greaterThanOrEqualTo(1)); // Should timeout now (2600ms > 2s)
        
        await subscription.cancel();
        await shortTimeoutService.dispose();
      });
    });

    group('State Streams', () {
      test('states stream emits state changes', () async {
        final states = <TimerServiceState>[];
        final subscription = service.states.listen(states.add);
        
        await service.start();
        service.startTracking();
        service.stopTracking();
        
        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();
        
        expect(states, [
          TimerServiceState.idle,
          TimerServiceState.tracking,
          TimerServiceState.idle,
        ]);
      });

      test('streams are closed after dispose', () async {
        await service.start();
        await service.dispose();
        
        expect(service.durationUpdates, emitsDone);
        expect(service.timeoutEvents, emitsDone);
        expect(service.states, emitsDone);
      });
    });
  });
}
