import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_player_service.dart';
import '../services/websocket_service.dart';
import '../services/realtime_api_client.dart';
import '../models/assistant_config.dart';

// Core providers

/// Provider for the secure storage service
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for checking if API key exists
final hasApiKeyProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(secureStorageServiceProvider);
  return await storage.hasApiKey();
});

/// Provider for the API key
final apiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(secureStorageServiceProvider);
  return await storage.getApiKey();
});

// Audio providers

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

// Realtime providers

/// Provider for the WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the Realtime API client
final realtimeApiClientProvider = Provider<RealtimeApiClient>((ref) {
  final client = RealtimeApiClient();
  ref.onDispose(() => client.dispose());
  return client;
});

/// Provider for connection state
final isConnectedProvider = StateProvider<bool>((ref) => false);

/// Provider for call duration in seconds
final callDurationProvider = StateProvider<int>((ref) => 0);

// Assistant providers

/// Provider for the assistant configuration
final assistantConfigProvider =
    StateNotifierProvider<AssistantConfigNotifier, AssistantConfig>((ref) {
  return AssistantConfigNotifier();
});

/// Notifier for assistant configuration state
class AssistantConfigNotifier extends StateNotifier<AssistantConfig> {
  AssistantConfigNotifier() : super(const AssistantConfig());

  /// Update the assistant name
  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  /// Update the assistant instructions
  void updateInstructions(String instructions) {
    state = state.copyWith(instructions: instructions);
  }

  /// Update the assistant voice
  void updateVoice(String voice) {
    state = state.copyWith(voice: voice);
  }

  /// Reset to default configuration
  void reset() {
    state = const AssistantConfig();
  }
}
