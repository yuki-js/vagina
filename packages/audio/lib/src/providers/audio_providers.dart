import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_player_service.dart';

/// Provider for the audio recorder service
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});

/// Provider for the audio player service
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final player = AudioPlayerService();
  ref.onDispose(() => player.dispose());
  return player;
});

/// Provider for mute state
final isMutedProvider = StateProvider<bool>((ref) => false);
