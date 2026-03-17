import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/voice_agent_info.dart';

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

  Future<void> _initialize() async {}

  Future<void> _startCall() async {}

  Future<void> endCall() async {
    if (_state == CallState.disposing || _state == CallState.disposed) {
      return;
    }

    _state = CallState.disposing;

    await _dispose();

    _state = CallState.disposed;
  }

  Future<void> _dispose() async {}
}
