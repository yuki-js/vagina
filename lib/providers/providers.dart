import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/audio_recorder_service.dart';
import 'package:vagina/services/audio_player_service.dart';
import 'package:vagina/services/websocket_service.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/tool_service.dart';
import 'package:vagina/services/call_feedback_service.dart';
import 'package:vagina/models/chat_message.dart';
import 'package:vagina/models/notepad_tab.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/services/log_service.dart';

// ============================================================================
// コアプロバイダ
// ============================================================================

/// ノートパッドサービスのプロバイダ
final notepadServiceProvider = Provider<NotepadService>((ref) {
  final service = NotepadService(
    logService: ref.read(logServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});


// ============================================================================
// オーディオプロバイダ
// ============================================================================

/// 音声録音サービスのプロバイダ
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});

/// 音声再生サービスのプロバイダ
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final player = AudioPlayerService(
    logService: ref.read(logServiceProvider),
  );
  ref.onDispose(() => player.dispose());
  return player;
});

/// マイクミュート状態のプロバイダ
final isMutedProvider = NotifierProvider<IsMutedNotifier, bool>(IsMutedNotifier.new);

/// マイクミュート状態の通知クラス
class IsMutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void set(bool value) {
    state = value;
  }
}

// ============================================================================
// リアルタイムAPIプロバイダ
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

/// 通話アクティブ状態のプロバイダ
final isCallActiveProvider = Provider<bool>((ref) {
  final callState = ref.watch(callStateProvider);
  return callState.maybeWhen(
    data: (state) => state == CallState.connecting || state == CallState.connected,
    orElse: () => false,
  );
});

/// スピーカーミュート状態のプロバイダ
final speakerMutedProvider = NotifierProvider<SpeakerMutedNotifier, bool>(SpeakerMutedNotifier.new);

/// スピーカーミュート状態の通知クラス
class SpeakerMutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

/// ノイズリダクション設定のプロバイダ
final noiseReductionProvider = NotifierProvider<NoiseReductionNotifier, String>(NoiseReductionNotifier.new);

/// ノイズリダクション設定の通知クラス
class NoiseReductionNotifier extends Notifier<String> {
  static const validValues = ['near', 'far'];
  
  @override
  String build() => 'near';

  void toggle() {
    state = state == 'near' ? 'far' : 'near';
  }

  void set(String value) {
    if (validValues.contains(value)) {
      state = value;
    }
  }
}

// ============================================================================
// ノートパッドプロバイダ
// ============================================================================

/// ノートパッドタブのプロバイダ（ストリーム）
final notepadTabsProvider = StreamProvider<List<NotepadTab>>((ref) {
  final notepadService = ref.read(notepadServiceProvider);
  return notepadService.tabsStream;
});

/// 選択中のノートパッドタブIDのプロバイダ（ストリーム）
final selectedNotepadTabIdProvider = StreamProvider<String?>((ref) {
  final notepadService = ref.read(notepadServiceProvider);
  return notepadService.selectedTabStream;
});

// ============================================================================
// ロギングプロバイダ
// ============================================================================

/// ログサービスのプロバイダ
final logServiceProvider = Provider<LogService>((ref) {
  return logService; // Use existing singleton for backward compatibility
});
