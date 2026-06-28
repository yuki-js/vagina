import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';

abstract final class RealtimeAdapterFactory {
  /// Create the hosted realtime adapter.
  ///
  /// [AppContainer] must be initialized before calling this method.
  static RealtimeAdapter create(VoiceAgentApiConfig apiConfig) {
    if (apiConfig is! HostedVoiceAgentApiConfig) {
      throw UnsupportedError(
        'Only hosted voice-agent realtime sessions are supported.',
      );
    }

    return VhrpRealtimeAdapter(tokenProvider: AppContainer.auth.getAccessToken);
  }
}
