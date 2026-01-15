import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_player_service.dart';
import 'core_providers.dart';

// ============================================================================
// Audio Providers - Only externally used providers
// ============================================================================

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

class IsMutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

/// スピーカーミュート状態のプロバイダ
final speakerMutedProvider = NotifierProvider<SpeakerMutedNotifier, bool>(SpeakerMutedNotifier.new);

class SpeakerMutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// ノイズリダクション設定のプロバイダ
final noiseReductionProvider = NotifierProvider<NoiseReductionNotifier, String>(NoiseReductionNotifier.new);

class NoiseReductionNotifier extends Notifier<String> {
  static const validValues = ['near', 'far'];
  
  @override
  String build() => 'near';

  void toggle() => state = state == 'near' ? 'far' : 'near';
  
  void set(String value) {
    if (validValues.contains(value)) state = value;
  }
}
