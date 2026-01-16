import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/models/chat_message.dart';
import 'package:vagina/services/call_service.dart';

part 'call_stream_providers.g.dart';

class CallStateInfo {
  final CallState? state;

  const CallStateInfo(this.state);

  bool get isActive =>
      state == CallState.connecting || state == CallState.connected;

  bool get isConnecting => state == CallState.connecting;

  bool get isConnected => state == CallState.connected;
}

class CallMetrics {
  final double amplitude;
  final int duration;
  final String? lastError;

  const CallMetrics({
    required this.amplitude,
    required this.duration,
    required this.lastError,
  });

  CallMetrics copyWith({
    double? amplitude,
    int? duration,
    String? lastError,
  }) {
    return CallMetrics(
      amplitude: amplitude ?? this.amplitude,
      duration: duration ?? this.duration,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Combined state for call UI.
///
/// This intentionally includes both connection state and frequently-updating
/// metrics (amplitude/duration/error).
class CallUiState {
  final CallState? state;
  final CallMetrics metrics;

  const CallUiState({
    required this.state,
    required this.metrics,
  });

  CallStateInfo get info => CallStateInfo(state);

  bool get isActive => info.isActive;
  bool get isConnecting => info.isConnecting;
  bool get isConnected => info.isConnected;

  CallUiState copyWith({
    CallState? state,
    CallMetrics? metrics,
  }) {
    return CallUiState(
      state: state ?? this.state,
      metrics: metrics ?? this.metrics,
    );
  }
}

@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref) {
  final service = ref.watch(callServiceProvider);
  return service.chatStream;
}

@riverpod
Stream<CallState> callState(Ref ref) {
  final service = ref.watch(callServiceProvider);
  return service.stateStream;
}

/// Combines [callStateProvider] with derived convenience flags.
///
/// This replaces the old derived `isCallActiveProvider`.
@riverpod
CallStateInfo callStateInfo(Ref ref) {
  final stateAsync = ref.watch(callStateProvider);
  return stateAsync.maybeWhen(
    data: (state) => CallStateInfo(state),
    orElse: () => const CallStateInfo(null),
  );
}

/// Consolidated stream for frequently-watched call metrics.
///
/// This replaces the old `amplitudeProvider`, `durationProvider`, and
/// `callErrorProvider`.
@riverpod
Stream<CallMetrics> callMetrics(Ref ref) {
  final service = ref.watch(callServiceProvider);

  final controller = StreamController<CallMetrics>.broadcast();
  var current = const CallMetrics(
    amplitude: 0.0,
    duration: 0,
    lastError: null,
  );

  void emit() {
    if (!controller.isClosed) {
      controller.add(current);
    }
  }

  // Emit initial state so consumers can render immediately.
  emit();

  final amplitudeSub = service.amplitudeStream.listen((amplitude) {
    current = current.copyWith(amplitude: amplitude);
    emit();
  });

  final durationSub = service.durationStream.listen((duration) {
    current = current.copyWith(duration: duration);
    emit();
  });

  final errorSub = service.errorStream.listen((error) {
    current = current.copyWith(lastError: error);
    emit();
  });

  ref.onDispose(() async {
    await amplitudeSub.cancel();
    await durationSub.cancel();
    await errorSub.cancel();
    await controller.close();
  });

  return controller.stream;
}

/// Combined stream for call UI.
///
/// Option A: single provider containing both call state and metrics.
@riverpod
Stream<CallUiState> callUiState(Ref ref) {
  final service = ref.watch(callServiceProvider);

  final controller = StreamController<CallUiState>.broadcast();
  CallState? currentState;
  var currentMetrics = const CallMetrics(
    amplitude: 0.0,
    duration: 0,
    lastError: null,
  );

  void emit() {
    if (!controller.isClosed) {
      controller.add(
        CallUiState(
          state: currentState,
          metrics: currentMetrics,
        ),
      );
    }
  }

  // Emit initial state so consumers can render immediately.
  emit();

  final stateSub = service.stateStream.listen((state) {
    currentState = state;
    emit();
  });

  final amplitudeSub = service.amplitudeStream.listen((amplitude) {
    currentMetrics = currentMetrics.copyWith(amplitude: amplitude);
    emit();
  });

  final durationSub = service.durationStream.listen((duration) {
    currentMetrics = currentMetrics.copyWith(duration: duration);
    emit();
  });

  final errorSub = service.errorStream.listen((error) {
    currentMetrics = currentMetrics.copyWith(lastError: error);
    emit();
  });

  ref.onDispose(() async {
    await stateSub.cancel();
    await amplitudeSub.cancel();
    await durationSub.cancel();
    await errorSub.cancel();
    await controller.close();
  });

  return controller.stream;
}
