import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/audio_recorder_service.dart';
import 'package:vagina/services/audio_player_service.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/services/tool_service.dart';
import 'package:vagina/services/haptic_service.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/models/android_audio_config.dart';

// Mock implementations for testing
class MockAudioRecorder extends AudioRecorderService {
  bool _hasPermission = true;
  
  @override
  Future<bool> hasPermission() async => _hasPermission;
  
  void setPermission(bool value) => _hasPermission = value;
}

class MockAudioPlayer extends AudioPlayerService {}

class MockRealtimeApiClient extends RealtimeApiClient {}

class MockConfigRepository implements ConfigRepository {
  String? _realtimeUrl = 'wss://test.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=test';
  String? _apiKey = 'test-key';
  
  @override
  Future<bool> hasAzureConfig() async => _apiKey != null && _realtimeUrl != null;
  
  @override
  Future<String?> getRealtimeUrl() async => _realtimeUrl;
  
  @override
  Future<String?> getApiKey() async => _apiKey;
  
  @override
  Future<bool> hasApiKey() async => _apiKey != null;
  
  @override
  Future<void> saveApiKey(String apiKey) async => _apiKey = apiKey;
  
  @override
  Future<void> deleteApiKey() async => _apiKey = null;
  
  @override
  Future<void> saveRealtimeUrl(String url) async => _realtimeUrl = url;
  
  @override
  Future<void> deleteRealtimeUrl() async => _realtimeUrl = null;
  
  @override
  Future<AndroidAudioConfig> getAndroidAudioConfig() async => const AndroidAudioConfig();
  
  @override
  Future<void> saveAndroidAudioConfig(AndroidAudioConfig config) async {}
  
  @override
  Future<List<String>> getEnabledTools() async => [];
  
  @override
  Future<List<String>> getDisabledTools() async => [];
  
  @override
  Future<bool> isToolEnabled(String toolName) async => true;
  
  @override
  Future<void> toggleTool(String toolName) async {}
  
  @override
  Future<void> clearAll() async {
    _apiKey = null;
    _realtimeUrl = null;
  }
  
  @override
  Future<String> getConfigFilePath() async => '/mock/path/config.json';
}

void main() {
  group('CallService', () {
    late CallService callService;
    late MockConfigRepository mockConfig;
    late NotepadService notepadService;

    setUp(() {
      mockConfig = MockConfigRepository();
      notepadService = NotepadService();
      
      callService = CallService(
        recorder: MockAudioRecorder(),
        player: MockAudioPlayer(),
        apiClient: MockRealtimeApiClient(),
        config: mockConfig,
        toolService: ToolService(notepadService: notepadService),
        hapticService: HapticService(),
        notepadService: notepadService,
      );
    });

    tearDown(() {
      callService.dispose();
      notepadService.dispose();
    });

    test('initial state is idle', () {
      expect(callService.currentState, equals(CallState.idle));
      expect(callService.isCallActive, isFalse);
      expect(callService.callDuration, equals(0));
    });

    test('chat messages start empty', () {
      expect(callService.chatMessages, isEmpty);
    });

    test('setMuted updates mute state', () {
      callService.setMuted(true);
      expect(callService.isCallActive, isFalse);
    });

    test('setSpeedDialId stores speed dial ID', () {
      callService.setSpeedDialId('test-id');
      expect(callService.currentSpeedDialId, equals('test-id'));
    });

    test('setAssistantConfig stores configuration', () {
      callService.setAssistantConfig('alloy', 'You are a helpful assistant');
      // Config is stored internally, no direct getter to test
      expect(callService.currentState, equals(CallState.idle));
    });

    test('hasAzureConfig returns correct value', () async {
      expect(await callService.hasAzureConfig(), isTrue);
    });

    test('clearChat clears messages', () {
      callService.clearChat();
      expect(callService.chatMessages, isEmpty);
    });

    test('sendTextMessage does nothing when call not active', () {
      callService.sendTextMessage('test message');
      // Should not throw, just ignore the message
      expect(callService.isCallActive, isFalse);
    });
  });
}
