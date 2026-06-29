import 'package:vagina/feat/call/models/realtime/realtime_thread.dart';

/// Server-backed call session history record.
///
/// List responses populate only [id], [startedAt], and [endedAt]. Detail-only
/// fields are nullable and are populated by the session detail API.
class CallSession {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? speedDialId;
  final String? voiceAgentId;
  final RealtimeThread? thread;

  const CallSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.speedDialId,
    this.voiceAgentId,
    this.thread,
  });

  int get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt).inSeconds;
  }

  int get visibleThreadItemCount {
    return thread?.items.where((item) => item.isVisible).length ?? 0;
  }

  CallSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    String? speedDialId,
    String? voiceAgentId,
    RealtimeThread? thread,
  }) {
    return CallSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      speedDialId: speedDialId ?? this.speedDialId,
      voiceAgentId: voiceAgentId ?? this.voiceAgentId,
      thread: thread ?? this.thread,
    );
  }
}
