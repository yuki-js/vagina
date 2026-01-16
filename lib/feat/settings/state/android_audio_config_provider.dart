import 'package:record/record.dart' show AndroidAudioSource, AudioManagerMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/models/android_audio_config.dart' as model;
import 'package:vagina/providers/providers.dart' show audioRecorderServiceProvider;

part 'android_audio_config_provider.g.dart';

/// Android audio configuration state.
///
/// Notes:
/// - Kept `keepAlive: true` because this is an app-wide preference-like state.
/// - Still applies the loaded/saved config to the recorder service.
@Riverpod(keepAlive: true)
class AndroidAudioConfig extends _$AndroidAudioConfig {
  @override
  Future<model.AndroidAudioConfig> build() async {
    final configRepo = ref.watch(configRepositoryProvider);
    final audioConfig = await configRepo.getAndroidAudioConfig();

    // Apply to recorder service.
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(audioConfig);

    return audioConfig;
  }

  Future<void> updateAudioSource(AndroidAudioSource source) async {
    final current = state.value ?? const model.AndroidAudioConfig();
    final newConfig = current.copyWith(audioSource: source);
    await _saveAndApply(newConfig);
  }

  Future<void> updateAudioManagerMode(AudioManagerMode mode) async {
    final current = state.value ?? const model.AndroidAudioConfig();
    final newConfig = current.copyWith(audioManagerMode: mode);
    await _saveAndApply(newConfig);
  }

  Future<void> reset() async {
    const defaultConfig = model.AndroidAudioConfig();
    await _saveAndApply(defaultConfig);
  }

  Future<void> _saveAndApply(model.AndroidAudioConfig config) async {
    final configRepo = ref.read(configRepositoryProvider);
    await configRepo.saveAndroidAudioConfig(config);

    // Apply to recorder service.
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(config);

    state = AsyncData(config);
  }
}
