import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/log_provider.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/feat/call/state/notepad_providers.dart';
import 'package:vagina/services/audio_player_service.dart';
import 'package:vagina/services/audio_recorder_service.dart';
import 'package:vagina/services/call_feedback_service.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/services/tool_service.dart';
import 'package:vagina/services/websocket_service.dart';

part 'call_service_providers.g.dart';

@Riverpod(keepAlive: true)
AudioRecorderService audioRecorderService(Ref ref) {
  final recorder = AudioRecorderService();
  ref.onDispose(() {
    recorder.dispose();
  });
  return recorder;
}

@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(Ref ref) {
  final player = AudioPlayerService(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(() {
    player.dispose();
  });
  return player;
}

@Riverpod(keepAlive: true)
WebSocketService webSocketService(Ref ref) {
  final service = WebSocketService(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@Riverpod(keepAlive: true)
RealtimeApiClient realtimeApiClient(Ref ref) {
  final client = RealtimeApiClient(
    webSocket: ref.watch(webSocketServiceProvider),
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(() {
    client.dispose();
  });
  return client;
}

@Riverpod(keepAlive: true)
ToolService toolService(Ref ref) {
  final notepadService = ref.watch(notepadServiceProvider);
  return ToolService(notepadService: notepadService);
}

@Riverpod(keepAlive: true)
CallFeedbackService callFeedbackService(Ref ref) {
  final service = CallFeedbackService(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@Riverpod(keepAlive: true)
CallService callService(Ref ref) {
  final service = CallService(
    recorder: ref.watch(audioRecorderServiceProvider),
    player: ref.watch(audioPlayerServiceProvider),
    apiClient: ref.watch(realtimeApiClientProvider),
    config: ref.watch(configRepositoryProvider),
    toolService: ref.watch(toolServiceProvider),
    notepadService: ref.watch(notepadServiceProvider),
    logService: ref.watch(logServiceProvider),
    feedbackService: ref.watch(callFeedbackServiceProvider),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
