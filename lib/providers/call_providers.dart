import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../services/realtime_api_client.dart';
import '../services/call_service.dart';
import '../services/tool_service.dart';
import '../services/call_feedback_service.dart';
import '../models/chat_message.dart';
import 'audio_providers.dart';
import 'core_providers.dart';
import 'repository_providers.dart';

// ============================================================================
// Call & Realtime API Providers
// ============================================================================

/// WebSocketサービスのプロバイダ
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(
    logService: ref.read(logServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Realtime APIクライアントのプロバイダ
final realtimeApiClientProvider = Provider<RealtimeApiClient>((ref) {
  final client = RealtimeApiClient(
    webSocket: ref.read(webSocketServiceProvider),
    logService: ref.read(logServiceProvider),
  );
  ref.onDispose(() => client.dispose());
  return client;
});

/// ツールサービスのプロバイダ
final toolServiceProvider = Provider<ToolService>((ref) {
  final notepadService = ref.read(notepadServiceProvider);
  return ToolService(notepadService: notepadService);
});

/// コールフィードバックサービスのプロバイダ (audio + haptic統合)
final callFeedbackServiceProvider = Provider<CallFeedbackService>((ref) {
  return CallFeedbackService(
    logService: ref.read(logServiceProvider),
  );
});

/// 通話サービスのプロバイダ
final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService(
    recorder: ref.read(audioRecorderServiceProvider),
    player: ref.read(audioPlayerServiceProvider),
    apiClient: ref.read(realtimeApiClientProvider),
    config: ref.read(configRepositoryProvider),
    toolService: ref.read(toolServiceProvider),
    notepadService: ref.read(notepadServiceProvider),
    logService: ref.read(logServiceProvider),
    feedbackService: ref.read(callFeedbackServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// チャットメッセージのプロバイダ
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.chatStream;
});

/// 通話状態のプロバイダ（ストリームベース）
final callStateProvider = StreamProvider<CallState>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.stateStream;
});

/// 音声振幅レベルのプロバイダ（ストリームベース）
final amplitudeProvider = StreamProvider<double>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.amplitudeStream;
});

/// 通話時間のプロバイダ（ストリームベース）
final durationProvider = StreamProvider<int>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.durationStream;
});

/// 通話エラーのプロバイダ（ストリームベース）
final callErrorProvider = StreamProvider<String>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.errorStream;
});

/// セッション保存完了通知のプロバイダ
/// セッション保存後にセッション履歴を自動更新するために使用
final sessionSavedProvider = StreamProvider<String>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.sessionSavedStream;
});

/// 通話アクティブ状態のプロバイダ
final isCallActiveProvider = Provider<bool>((ref) {
  final callState = ref.watch(callStateProvider);
  return callState.maybeWhen(
    data: (state) => state == CallState.connecting || state == CallState.connected,
    orElse: () => false,
  );
});
