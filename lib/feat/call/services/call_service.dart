import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';
import 'package:vagina/feat/call/services/notepad_service.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/feat/call/services/tool_runner.dart';

/// One-way lifecycle state for a single call session.
enum CallState {
  uninitialized, // constructed, but start not triggered
  connecting, // starting session resources and connecting
  active, // connected, and call end not triggered
  disposing, // call end triggered, and cleanup in progress
  disposed, // cleanup completed, and service is no longer reusable
}

/// Session-scoped call service instantiated by the call screen.
class CallService {
  final VoiceAgentInfo voiceAgent;
  final List<TextAgentInfo> textAgents;

  final RealtimeService _realtimeService = RealtimeService();
  final ToolRunner _toolRunner = ToolRunner();
  final NotepadService _notepadService = NotepadService();

  CallState _state = CallState.uninitialized;

  CallService({
    required this.voiceAgent,
    this.textAgents = const [],
  });

  CallState get state => _state;

  Future<void> startCall() async {
    if (_state != CallState.uninitialized) {
      throw StateError(
          'startCall() can only be called from uninitialized state.');
    }

    await _initialize();
    _state = CallState.connecting;

    await _startCall();

    _state = CallState.active;
  }

  Future<void> _initialize() async {
    await Future.wait<void>([
      _realtimeService.start(),
      _toolRunner.start(),
      _notepadService.start(),
    ]);
  }

  Future<void> _startCall() async {}

  Future<void> endCall() async {
    if (_state == CallState.disposing || _state == CallState.disposed) {
      return;
    }

    _state = CallState.disposing;

    await _dispose();

    _state = CallState.disposed;
  }

  Future<void> _dispose() async {
    await Future.wait<void>([
      _realtimeService.dispose(),
      _toolRunner.dispose(),
      _notepadService.dispose(),
    ]);
  }
}
