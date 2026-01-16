import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../../models/android_audio_config.dart';
import '../../../providers/repository_providers.dart';
import '../../call/providers/call_providers.dart';

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
// UI設定プロバイダ
// ============================================================================

/// Cupertinoスタイル設定のプロバイダ（Material vs Cupertino）
final useCupertinoStyleProvider =
    NotifierProvider<CupertinoStyleNotifier, bool>(
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
