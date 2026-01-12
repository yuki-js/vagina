import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../services/notepad_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_player_service.dart';
import '../services/websocket_service.dart';
import '../services/realtime_api_client.dart';
import '../services/call_service.dart';
import '../services/tool_service.dart';
import '../services/haptic_service.dart';
import '../models/assistant_config.dart';
import '../models/chat_message.dart';
import '../models/notepad_tab.dart';
import '../models/android_audio_config.dart';
import '../models/call_session.dart';
import '../models/speed_dial.dart';
import '../repositories/repository_factory.dart';
import 'repository_providers.dart';
import '../services/log_service.dart';

// ============================================================================
// コアプロバイダ
// ============================================================================

/// ノートパッドサービスのプロバイダ
final notepadServiceProvider = Provider<NotepadService>((ref) {
  final service = NotepadService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// APIキー存在確認のプロバイダ
final hasApiKeyProvider = FutureProvider<bool>((ref) async {
  final config = ref.read(configRepositoryProvider);
  return await config.hasApiKey();
});

/// APIキーのプロバイダ
final apiKeyProvider = FutureProvider<String?>((ref) async {
  final config = ref.read(configRepositoryProvider);
  return await config.getApiKey();
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
  final player = AudioPlayerService();
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
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Realtime APIクライアントのプロバイダ
final realtimeApiClientProvider = Provider<RealtimeApiClient>((ref) {
  final client = RealtimeApiClient();
  ref.onDispose(() => client.dispose());
  return client;
});

/// ツールサービスのプロバイダ
final toolServiceProvider = Provider<ToolService>((ref) {
  final notepadService = ref.read(notepadServiceProvider);
  return ToolService(notepadService: notepadService);
});

/// ハプティックフィードバックサービスのプロバイダ
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService();
});

/// 通話サービスのプロバイダ
final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService(
    recorder: ref.read(audioRecorderServiceProvider),
    player: ref.read(audioPlayerServiceProvider),
    apiClient: ref.read(realtimeApiClientProvider),
    config: ref.read(configRepositoryProvider),
    toolService: ref.read(toolServiceProvider),
    hapticService: ref.read(hapticServiceProvider),
    notepadService: ref.read(notepadServiceProvider),
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
// アシスタントプロバイダ
// ============================================================================

/// アシスタント設定のプロバイダ
final assistantConfigProvider =
    NotifierProvider<AssistantConfigNotifier, AssistantConfig>(AssistantConfigNotifier.new);

/// アシスタント設定の通知クラス
class AssistantConfigNotifier extends Notifier<AssistantConfig> {
  @override
  AssistantConfig build() => const AssistantConfig();

  /// アシスタント名を更新
  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  /// アシスタントの指示を更新
  void updateInstructions(String instructions) {
    state = state.copyWith(instructions: instructions);
  }

  /// アシスタントの声を更新
  void updateVoice(String voice) {
    state = state.copyWith(voice: voice);
  }

  /// デフォルト設定にリセット
  void reset() {
    state = const AssistantConfig();
  }
}

// ============================================================================
// Androidオーディオプロバイダ
// ============================================================================

/// Androidオーディオ設定のプロバイダ
final androidAudioConfigProvider =
    AsyncNotifierProvider<AndroidAudioConfigNotifier, AndroidAudioConfig>(
        AndroidAudioConfigNotifier.new);

/// Androidオーディオ設定の通知クラス
class AndroidAudioConfigNotifier extends AsyncNotifier<AndroidAudioConfig> {
  @override
  Future<AndroidAudioConfig> build() async {
    final config = ref.read(configRepositoryProvider);
    final audioConfig = await config.getAndroidAudioConfig();
    // 録音サービスに設定を適用
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(audioConfig);
    return audioConfig;
  }

  /// オーディオソースを更新
  Future<void> updateAudioSource(AndroidAudioSource source) async {
    final current = state.value ?? const AndroidAudioConfig();
    final newConfig = current.copyWith(audioSource: source);
    await _saveAndApply(newConfig);
  }

  /// オーディオマネージャーモードを更新
  Future<void> updateAudioManagerMode(AudioManagerMode mode) async {
    final current = state.value ?? const AndroidAudioConfig();
    final newConfig = current.copyWith(audioManagerMode: mode);
    await _saveAndApply(newConfig);
  }

  /// 設定を保存して適用
  Future<void> _saveAndApply(AndroidAudioConfig config) async {
    final configRepo = ref.read(configRepositoryProvider);
    await configRepo.saveAndroidAudioConfig(config);
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(config);
    state = AsyncData(config);
  }

  /// デフォルト設定にリセット
  Future<void> reset() async {
    const defaultConfig = AndroidAudioConfig();
    await _saveAndApply(defaultConfig);
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
// スピードダイヤルプロバイダ
// ============================================================================

/// スピードダイヤルのプロバイダ（リポジトリ使用）
final speedDialsProvider = FutureProvider<List<SpeedDial>>((ref) async {
  return await RepositoryFactory.speedDials.getAll();
});

/// スピードダイヤル更新トリガーのプロバイダ
final speedDialsRefreshProvider = NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

/// 自動更新スピードダイヤルのプロバイダ（リポジトリ使用）
final refreshableSpeedDialsProvider = FutureProvider<List<SpeedDial>>((ref) async {
  // 更新トリガーを監視
  ref.watch(speedDialsRefreshProvider);
  return await RepositoryFactory.speedDials.getAll();
});

// ============================================================================
// セッション履歴プロバイダ
// ============================================================================

/// セッション履歴のプロバイダ（リポジトリ使用）
final callSessionsProvider = FutureProvider<List<CallSession>>((ref) async {
  return await RepositoryFactory.callSessions.getAll();
});

/// セッション履歴更新トリガーのプロバイダ
final callSessionsRefreshProvider = NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

/// 自動更新セッション履歴のプロバイダ（リポジトリ使用）
final refreshableCallSessionsProvider = FutureProvider<List<CallSession>>((ref) async {
  // 更新トリガーを監視
  ref.watch(callSessionsRefreshProvider);
  return await RepositoryFactory.callSessions.getAll();
});

/// シンプルな更新通知クラス
class RefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() {
    state++;
  }
}

// ============================================================================
// UI設定プロバイダ
// ============================================================================

/// Cupertinoスタイル設定のプロバイダ（Material vs Cupertino）
final useCupertinoStyleProvider = NotifierProvider<CupertinoStyleNotifier, bool>(
  CupertinoStyleNotifier.new,
);

/// Cupertinoスタイル設定の通知クラス
class CupertinoStyleNotifier extends Notifier<bool> {
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
// ロギングプロバイダ
// ============================================================================

/// ログサービスのプロバイダ
final logServiceProvider = Provider<LogService>((ref) {
  return logService; // Use existing singleton for backward compatibility
});
