import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../models/assistant_config.dart';
import '../../models/android_audio_config.dart';
import '../../providers/repository_providers.dart';
import '../../services/audio_recorder_service.dart';

// ============================================================================
// Settings Screen Local Providers  
// ============================================================================

final assistantConfigProvider = NotifierProvider<AssistantConfigNotifier, AssistantConfig>(AssistantConfigNotifier.new);

class AssistantConfigNotifier extends Notifier<AssistantConfig> {
  @override
  AssistantConfig build() => const AssistantConfig();
  void updateName(String name) => state = state.copyWith(name: name);
  void updateInstructions(String instructions) => state = state.copyWith(instructions: instructions);
  void updateVoice(String voice) => state = state.copyWith(voice: voice);
  void reset() => state = const AssistantConfig();
}

final androidAudioConfigProvider = AsyncNotifierProvider<AndroidAudioConfigNotifier, AndroidAudioConfig>(AndroidAudioConfigNotifier.new);

class AndroidAudioConfigNotifier extends AsyncNotifier<AndroidAudioConfig> {
  @override
  Future<AndroidAudioConfig> build() async {
    final config = ref.read(configRepositoryProvider);
    final audioConfig = await config.getAndroidAudioConfig();
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(audioConfig);
    return audioConfig;
  }

  Future<void> updateAudioSource(AndroidAudioSource source) async {
    final current = state.value ?? const AndroidAudioConfig();
    await _saveAndApply(current.copyWith(audioSource: source));
  }

  Future<void> updateAudioManagerMode(AudioManagerMode mode) async {
    final current = state.value ?? const AndroidAudioConfig();
    await _saveAndApply(current.copyWith(audioManagerMode: mode));
  }

  Future<void> _saveAndApply(AndroidAudioConfig config) async {
    await ref.read(configRepositoryProvider).saveAndroidAudioConfig(config);
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(config);
    state = AsyncData(config);
  }

  Future<void> reset() async => await _saveAndApply(const AndroidAudioConfig());
}

// Local audio recorder service provider for settings screen
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});
