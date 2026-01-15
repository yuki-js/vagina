import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_player_service.dart';
import '../models/android_audio_config.dart';
import 'repository_providers.dart';
import 'core_providers.dart';

// ============================================================================
// Audio Providers
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
