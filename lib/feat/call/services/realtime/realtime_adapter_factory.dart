import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/oai_cc/oai_cc_adapter.dart';

abstract final class RealtimeAdapterFactory {
  /// Create an adapter instance based on the configuration.
  static RealtimeAdapter create(VoiceAgentApiConfig apiConfig) {
    return switch (apiConfig) {
      SelfhostedVoiceAgentApiConfig(
        providerType: VoiceAgentProviderType.openai,
      ) =>
        OaiRealtimeAdapter(),
      SelfhostedVoiceAgentApiConfig(
        providerType: VoiceAgentProviderType.openaiCc,
      ) =>
        OaiCcRealtimeAdapter(),
      SelfhostedVoiceAgentApiConfig(
        providerType: VoiceAgentProviderType.gemini,
      ) =>
        throw UnsupportedError(
          'Gemini adapter is not implemented yet.',
        ),
      HostedVoiceAgentApiConfig() => throw UnsupportedError(
        'ホステッドプロトコルは現在実装中です。',
      ),
      _ => throw UnsupportedError(
        'Unsupported voice agent api config for realtime service.',
      ),
    };
  }

  /// Run a connection test.
  static Future<void> testConnection(VoiceAgentApiConfig apiConfig) async {
    switch (apiConfig) {
      case SelfhostedVoiceAgentApiConfig(
          providerType: VoiceAgentProviderType.openai
        ):
        await OaiRealtimeAdapter.testConnection(
          apiConfig.baseUrl,
          apiConfig.apiKey,
          modality: apiConfig.modality,
        );
      case SelfhostedVoiceAgentApiConfig(
          providerType: VoiceAgentProviderType.openaiCc
        ):
        await OaiCcRealtimeAdapter.testConnection(
          apiConfig.baseUrl,
          apiConfig.apiKey,
          modality: apiConfig.modality,
        );
      case SelfhostedVoiceAgentApiConfig(
          providerType: VoiceAgentProviderType.gemini
        ):
        throw UnsupportedError(
          'Gemini adapter is not implemented yet.',
        );
      case HostedVoiceAgentApiConfig():
        throw UnsupportedError('これから実装します。');
      default:
        throw UnsupportedError(
          'Connection test is not supported for this provider type.',
        );
    }
  }
}
