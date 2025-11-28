import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../services/storage_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_player_service.dart';
import '../services/websocket_service.dart';
import '../services/realtime_api_client.dart';
import '../services/call_service.dart';
import '../services/tool_service.dart';
import '../models/assistant_config.dart';
import '../models/chat_message.dart';
import '../models/android_audio_config.dart';

// Core providers

/// Provider for the storage service
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provider for checking if API key exists
final hasApiKeyProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(storageServiceProvider);
  return await storage.hasApiKey();
});

/// Provider for the API key
final apiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(storageServiceProvider);
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
final isMutedProvider = NotifierProvider<IsMutedNotifier, bool>(IsMutedNotifier.new);

/// Notifier for mute state
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

/// Provider for the tool service
final toolServiceProvider = Provider<ToolService>((ref) {
  final storage = ref.read(storageServiceProvider);
  return ToolService(storage: storage);
});

/// Provider for the call service
final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService(
    recorder: ref.read(audioRecorderServiceProvider),
    player: ref.read(audioPlayerServiceProvider),
    apiClient: ref.read(realtimeApiClientProvider),
    storage: ref.read(storageServiceProvider),
    toolService: ref.read(toolServiceProvider),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for chat messages
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.chatStream;
});

/// Provider for call state (stream-based)
final callStateProvider = StreamProvider<CallState>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.stateStream;
});

/// Provider for audio amplitude level (stream-based)
final amplitudeProvider = StreamProvider<double>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.amplitudeStream;
});

/// Provider for call duration (stream-based)
final durationProvider = StreamProvider<int>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.durationStream;
});

/// Provider for call errors (stream-based)
final callErrorProvider = StreamProvider<String>((ref) {
  final callService = ref.read(callServiceProvider);
  return callService.errorStream;
});

/// Provider for whether call is active
final isCallActiveProvider = Provider<bool>((ref) {
  final callState = ref.watch(callStateProvider);
  return callState.maybeWhen(
    data: (state) => state == CallState.connecting || state == CallState.connected,
    orElse: () => false,
  );
});

/// Provider for double speed playback state
final doubleSpeedProvider = NotifierProvider<DoubleSpeedNotifier, bool>(DoubleSpeedNotifier.new);

/// Notifier for double speed playback state
class DoubleSpeedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

/// Provider for noise reduction setting
final noiseReductionProvider = NotifierProvider<NoiseReductionNotifier, String>(NoiseReductionNotifier.new);

/// Notifier for noise reduction setting
class NoiseReductionNotifier extends Notifier<String> {
  @override
  String build() => 'near';

  void toggle() {
    state = state == 'near' ? 'far' : 'near';
  }
}

// Assistant providers

/// Provider for the assistant configuration
final assistantConfigProvider =
    NotifierProvider<AssistantConfigNotifier, AssistantConfig>(AssistantConfigNotifier.new);

/// Notifier for assistant configuration state
class AssistantConfigNotifier extends Notifier<AssistantConfig> {
  @override
  AssistantConfig build() => const AssistantConfig();

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

// Android Audio providers

/// Provider for Android audio configuration
final androidAudioConfigProvider =
    AsyncNotifierProvider<AndroidAudioConfigNotifier, AndroidAudioConfig>(
        AndroidAudioConfigNotifier.new);

/// Notifier for Android audio configuration state
class AndroidAudioConfigNotifier extends AsyncNotifier<AndroidAudioConfig> {
  @override
  Future<AndroidAudioConfig> build() async {
    final storage = ref.read(storageServiceProvider);
    final config = await storage.getAndroidAudioConfig();
    // Apply config to recorder service
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(config);
    return config;
  }

  /// Update the audio source
  Future<void> updateAudioSource(AndroidAudioSource source) async {
    final current = state.value ?? const AndroidAudioConfig();
    final newConfig = current.copyWith(audioSource: source);
    await _saveAndApply(newConfig);
  }

  /// Update the audio manager mode
  Future<void> updateAudioManagerMode(AudioManagerMode mode) async {
    final current = state.value ?? const AndroidAudioConfig();
    final newConfig = current.copyWith(audioManagerMode: mode);
    await _saveAndApply(newConfig);
  }

  /// Save and apply the configuration
  Future<void> _saveAndApply(AndroidAudioConfig config) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveAndroidAudioConfig(config);
    ref.read(audioRecorderServiceProvider).setAndroidAudioConfig(config);
    state = AsyncData(config);
  }

  /// Reset to default configuration
  Future<void> reset() async {
    const defaultConfig = AndroidAudioConfig();
    await _saveAndApply(defaultConfig);
  }
}
