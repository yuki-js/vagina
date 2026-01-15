import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/call_service.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/realtime_api_client.dart';
import '../../services/websocket_service.dart';
import '../../services/tool_service.dart';
import '../../services/call_feedback_service.dart';
import '../../models/chat_message.dart';
import '../../models/notepad_tab.dart';
import '../../providers/core_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/audio_providers.dart';

// ============================================================================
// Call Screen Local Providers
// These are ONLY used within the call feature screens
// ============================================================================

/// 通話サービス - call画面専用
final callServiceProvider = Provider<CallService>((ref) {
  final recorder = AudioRecorderService();
  final player = ref.read(audioPlayerServiceProvider);
  final webSocket = WebSocketService(logService: ref.read(logServiceProvider));
  final apiClient = RealtimeApiClient(webSocket: webSocket, logService: ref.read(logServiceProvider));
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

final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) => ref.read(callServiceProvider).chatStream);
final callStateProvider = StreamProvider<CallState>((ref) => ref.read(callServiceProvider).stateStream);
final amplitudeProvider = StreamProvider<double>((ref) => ref.read(callServiceProvider).amplitudeStream);
final durationProvider = StreamProvider<int>((ref) => ref.read(callServiceProvider).durationStream);
final callErrorProvider = StreamProvider<String>((ref) => ref.read(callServiceProvider).errorStream);
final sessionSavedProvider = StreamProvider<String>((ref) => ref.read(callServiceProvider).sessionSavedStream);

final isCallActiveProvider = Provider<bool>((ref) {
  final callState = ref.watch(callStateProvider);
  return callState.maybeWhen(
    data: (state) => state == CallState.connecting || state == CallState.connected,
    orElse: () => false,
  );
});

final notepadTabsProvider = StreamProvider<List<NotepadTab>>((ref) => ref.read(notepadServiceProvider).tabsStream);
final selectedNotepadTabIdProvider = StreamProvider<String?>((ref) => ref.read(notepadServiceProvider).selectedTabStream);
