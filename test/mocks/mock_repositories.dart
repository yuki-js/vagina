import 'package:mockito/annotations.dart';
import 'package:vagina/interfaces/call_session_repository.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/memory_repository.dart';
import 'package:vagina/interfaces/speed_dial_repository.dart';
import 'package:vagina/interfaces/text_agent_repository.dart';
import 'package:vagina/repositories/preferences_repository.dart';
import 'package:vagina/services/audio_player_service.dart';
import 'package:vagina/services/audio_recorder_service.dart';
import 'package:vagina/services/call_feedback_service.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/services/text_agent_job_runner.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/services/tool_service.dart';
import 'package:vagina/services/websocket_service.dart';

// Generate mocks with mockito
@GenerateMocks([
  CallSessionRepository,
  ConfigRepository,
  MemoryRepository,
  SpeedDialRepository,
  PreferencesRepository,
  TextAgentRepository,
  LogService,
  AudioRecorderService,
  AudioPlayerService,
  CallFeedbackService,
  WebSocketService,
  RealtimeApiClient,
  ToolService,
  NotepadService,
  CallService,
  TextAgentService,
  TextAgentJobRunner,
])
void main() {}
