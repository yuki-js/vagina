import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/models/chat_message.dart';
import 'package:vagina/services/call_service.dart';

part 'call_stream_providers.g.dart';

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

@riverpod
Stream<double> amplitude(Ref ref) {
  final service = ref.watch(callServiceProvider);
  return service.amplitudeStream;
}

@riverpod
Stream<int> duration(Ref ref) {
  final service = ref.watch(callServiceProvider);
  return service.durationStream;
}

@riverpod
Stream<String> callError(Ref ref) {
  final service = ref.watch(callServiceProvider);
  return service.errorStream;
}

@riverpod
bool isCallActive(Ref ref) {
  final callStateAsync = ref.watch(callStateProvider);
  return callStateAsync.maybeWhen(
    data: (state) => state == CallState.connecting || state == CallState.connected,
    orElse: () => false,
  );
}
