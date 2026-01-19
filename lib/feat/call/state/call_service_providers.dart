import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vagina/core/state/log_provider.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/services/audio/call_audio_service.dart';
import 'package:vagina/services/call_feedback_service.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/services/text_agent_job_runner.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/services/tool_service.dart';

part 'call_service_providers.g.dart';

@riverpod
CallAudioService callAudioService(Ref ref) {
  final service = CallAudioService(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@riverpod
RealtimeApiClient realtimeApiClient(Ref ref) {
  final client = RealtimeApiClient(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(() {
    client.dispose();
  });
  return client;
}

@Riverpod(keepAlive: true)
ToolService toolService(Ref ref) {
  final configRepository = ref.watch(configRepositoryProvider);
  return ToolService(
    configRepository: configRepository,
  );
}

@riverpod
CallFeedbackService callFeedbackService(Ref ref) {
  final service = CallFeedbackService(
    logService: ref.watch(logServiceProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@riverpod
CallService callService(Ref ref) {
  final service = CallService(
    audioService: ref.watch(callAudioServiceProvider),
    apiClient: ref.watch(realtimeApiClientProvider),
    config: ref.watch(configRepositoryProvider),
    sessionRepository: ref.watch(callSessionRepositoryProvider),
    memoryRepository: ref.watch(memoryRepositoryProvider),
    agentRepository: ref.watch(textAgentRepositoryProvider),
    textAgentService: ref.watch(textAgentServiceProvider),
    textAgentJobRunner: ref.watch(textAgentJobRunnerProvider),
    logService: ref.watch(logServiceProvider),
    feedbackService: ref.watch(callFeedbackServiceProvider),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
