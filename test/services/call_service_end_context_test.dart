import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vagina/models/call_session.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/services/call_service.dart';

import '../mocks/mock_repositories.mocks.dart';

void main() {
  group('CallService endContext', () {
    late CallService callService;
    late MockAudioRecorderService mockRecorder;
    late MockAudioPlayerService mockPlayer;
    late MockRealtimeApiClient mockApiClient;
    late MockConfigRepository mockConfig;
    late MockCallSessionRepository mockSessionRepository;
    late MockNotepadService mockNotepadService;
    late MockMemoryRepository mockMemoryRepository;
    late MockLogService mockLogService;
    late MockCallFeedbackService mockFeedback;
    late MockTextAgentRepository mockAgentRepository;
    late MockTextAgentService mockTextAgentService;
    late MockTextAgentJobRunner mockTextAgentJobRunner;

    setUp(() {
      mockRecorder = MockAudioRecorderService();
      mockPlayer = MockAudioPlayerService();
      mockApiClient = MockRealtimeApiClient();
      mockConfig = MockConfigRepository();
      mockSessionRepository = MockCallSessionRepository();
      mockNotepadService = MockNotepadService();
      mockMemoryRepository = MockMemoryRepository();
      mockLogService = MockLogService();
      mockFeedback = MockCallFeedbackService();
      mockAgentRepository = MockTextAgentRepository();
      mockTextAgentService = MockTextAgentService();
      mockTextAgentJobRunner = MockTextAgentJobRunner();

      callService = CallService(
        recorder: mockRecorder,
        player: mockPlayer,
        apiClient: mockApiClient,
        config: mockConfig,
        sessionRepository: mockSessionRepository,
        notepadService: mockNotepadService,
        memoryRepository: mockMemoryRepository,
        agentRepository: mockAgentRepository,
        textAgentService: mockTextAgentService,
        textAgentJobRunner: mockTextAgentJobRunner,
        logService: mockLogService,
        feedbackService: mockFeedback,
      );
    });

    tearDown(() async {
      await callService.dispose();
    });

    test('setEndContext stores context', () {
      const testContext = 'ultra_long processing in progress';
      
      callService.setEndContext(testContext);
      
      // Context is stored internally (private field _endContext)
      // We verify it works by checking the saved session later
    });

    test('setEndContext ignores null or empty context', () {
      callService.setEndContext(null);
      callService.setEndContext('');
      
      // Should not throw or cause issues
    });

    test('getLastEndContext returns null when no sessions exist', () async {
      when(mockSessionRepository.getAll()).thenAnswer((_) async => []);
      
      final context = await callService.getLastEndContext();
      
      expect(context, isNull);
      verify(mockSessionRepository.getAll()).called(1);
    });

    test('getLastEndContext returns context from most recent session', () async {
      final now = DateTime.now();
      final oldSession = CallSession(
        id: '1',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 2)),
        duration: 60,
        speedDialId: SpeedDial.defaultId,
        endContext: 'old context',
      );
      final recentSession = CallSession(
        id: '2',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.subtract(const Duration(hours: 1)),
        duration: 60,
        speedDialId: SpeedDial.defaultId,
        endContext: 'recent context',
      );
      
      when(mockSessionRepository.getAll())
          .thenAnswer((_) async => [oldSession, recentSession]);
      
      final context = await callService.getLastEndContext();
      
      expect(context, equals('recent context'));
    });

    test('getLastEndContext returns null for sessions older than 24 hours', () async {
      final oldTime = DateTime.now().subtract(const Duration(hours: 25));
      final oldSession = CallSession(
        id: '1',
        startTime: oldTime,
        endTime: oldTime,
        duration: 60,
        speedDialId: SpeedDial.defaultId,
        endContext: 'expired context',
      );
      
      when(mockSessionRepository.getAll()).thenAnswer((_) async => [oldSession]);
      
      final context = await callService.getLastEndContext();
      
      expect(context, isNull);
    });

    test('getLastEndContext returns null when most recent session has no context', () async {
      final now = DateTime.now();
      final recentSession = CallSession(
        id: '1',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now.subtract(const Duration(hours: 1)),
        duration: 60,
        speedDialId: SpeedDial.defaultId,
        endContext: null,
      );
      
      when(mockSessionRepository.getAll())
          .thenAnswer((_) async => [recentSession]);
      
      final context = await callService.getLastEndContext();
      
      expect(context, isNull);
    });

    test('getLastEndContext handles repository errors gracefully', () async {
      when(mockSessionRepository.getAll())
          .thenThrow(Exception('Database error'));
      
      final context = await callService.getLastEndContext();
      
      expect(context, isNull);
    });

    test('getLastEndContext uses startTime when endTime is null', () async {
      final now = DateTime.now();
      final session = CallSession(
        id: '1',
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: null, // No end time
        duration: 60,
        speedDialId: SpeedDial.defaultId,
        endContext: 'test context',
      );
      
      when(mockSessionRepository.getAll()).thenAnswer((_) async => [session]);
      
      final context = await callService.getLastEndContext();
      
      expect(context, equals('test context'));
    });
  });
}
