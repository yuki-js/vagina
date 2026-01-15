import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/call_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_player_service.dart';
import '../services/realtime_api_client.dart';
import '../services/websocket_service.dart';
import '../services/tool_service.dart';
import '../services/call_feedback_service.dart';
import '../models/chat_message.dart';
import 'core_providers.dart';
import 'repository_providers.dart';
import 'audio_providers.dart';

// ============================================================================
// Call Providers - Simplified with minimal exposure
// ============================================================================

/// 通話サービスのプロバイダ
/// Internal services are created here and not exposed separately
final callServiceProvider = Provider<CallService>((ref) {
  // Create internal dependencies
  final recorder = AudioRecorderService();
  final player = ref.read(audioPlayerServiceProvider);
  final webSocket = WebSocketService(logService: ref.read(logServiceProvider));
  final apiClient = RealtimeApiClient(
    webSocket: webSocket,
    logService: ref.read(logServiceProvider),
  );
  final toolService = ToolService(notepadService: ref.read(notepadServiceProvider));
  final feedbackService = CallFeedbackService(logService: ref.read(logServiceProvider));
  
  final service = CallService(
    recorder: recorder,
    player: player,
    apiClient: apiClient,
    config: ref.read(configRepositoryProvider),
    toolService: toolService,
    notepadService: ref.read(notepadServiceProvider),
    logService: ref.read(logServiceProvider),
    feedbackService: feedbackService,
  );
  
  ref.onDispose(() {
    service.dispose();
    recorder.dispose();
    webSocket.dispose();
    apiClient.dispose();
  });
  
  return service;
});

// Stream providers for call state
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  return ref.read(callServiceProvider).chatStream;
});

final callStateProvider = StreamProvider<CallState>((ref) {
  return ref.read(callServiceProvider).stateStream;
});

final amplitudeProvider = StreamProvider<double>((ref) {
  return ref.read(callServiceProvider).amplitudeStream;
});

final durationProvider = StreamProvider<int>((ref) {
  return ref.read(callServiceProvider).durationStream;
});

final callErrorProvider = StreamProvider<String>((ref) {
  return ref.read(callServiceProvider).errorStream;
});

final sessionSavedProvider = StreamProvider<String>((ref) {
  return ref.read(callServiceProvider).sessionSavedStream;
});

final isCallActiveProvider = Provider<bool>((ref) {
  final callState = ref.watch(callStateProvider);
  return callState.maybeWhen(
    data: (state) => state == CallState.connecting || state == CallState.connected,
    orElse: () => false,
  );
});

// Reexport ToolService provider for tools_tab
final toolServiceProvider = Provider<ToolService>((ref) {
  return ToolService(notepadService: ref.read(notepadServiceProvider));
});

// Reexport RealtimeApiClient provider for settings
final realtimeApiClientProvider = Provider<RealtimeApiClient>((ref) {
  final webSocket = WebSocketService(logService: ref.read(logServiceProvider));
  return RealtimeApiClient(
    webSocket: webSocket,
    logService: ref.read(logServiceProvider),
  );
});
