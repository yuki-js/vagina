import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/log_provider.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/services/audio/call_audio_service.dart';
import 'package:vagina/services/call_feedback_service.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/services/tool_service.dart';

part 'call_service_providers.g.dart';

@riverpod
CallAudioService callAudioService(Ref ref) {
  final logService = ref.watch(logServiceProvider);
  final service = CallAudioService(
    logService: logService,
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@riverpod
RealtimeApiClient realtimeApiClient(Ref ref) {
  final logService = ref.watch(logServiceProvider);
  final client = RealtimeApiClient(
    logService: logService,
  );
  ref.onDispose(() {
    client.dispose();
  });
  return client;
}

@Riverpod(keepAlive: true)
ToolService toolService(Ref ref) {
  return ToolService();
}

@riverpod
CallFeedbackService callFeedbackService(Ref ref) {
  final logService = ref.watch(logServiceProvider);
  final service = CallFeedbackService(
    logService: logService,
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@riverpod
CallService callService(Ref ref) {
  final logService = ref.watch(logServiceProvider);
  final service = CallService(
    audioService: ref.watch(callAudioServiceProvider),
    apiClient: ref.watch(realtimeApiClientProvider),
    config: ref.watch(configRepositoryProvider),
    speedDialRepo: ref.watch(speedDialRepositoryProvider),
    sessionRepository: ref.watch(callSessionRepositoryProvider),
    toolStorage: ref.watch(toolStorageProvider),
    logService: logService,
    feedbackService: ref.watch(callFeedbackServiceProvider),
  );

  ref.onDispose(() {
    logService.debug('CallServiceProvider', 'Disposing CallService');
    service.dispose();
  });

  return service;
}
