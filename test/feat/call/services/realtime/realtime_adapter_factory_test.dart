import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/oai_cc/oai_cc_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter_factory.dart';

void main() {
  group('RealtimeAdapterFactory.create', () {
    test('creates OpenAI realtime adapter for self-hosted openai config', () {
      final adapter = RealtimeAdapterFactory.create(
        const SelfhostedVoiceAgentApiConfig(
          providerType: VoiceAgentProviderType.openai,
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
        ),
      );

      expect(adapter, isA<OaiRealtimeAdapter>());
    });

    test('creates OpenAI CC adapter for self-hosted openaiCc config', () {
      final adapter = RealtimeAdapterFactory.create(
        const SelfhostedVoiceAgentApiConfig(
          providerType: VoiceAgentProviderType.openaiCc,
          baseUrl: 'https://example.com/v1',
          apiKey: 'test-key',
        ),
      );

      expect(adapter, isA<OaiCcRealtimeAdapter>());
    });

    test('throws for self-hosted gemini config', () {
      expect(
        () => RealtimeAdapterFactory.create(
          const SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.gemini,
            baseUrl: 'https://example.com/v1',
            apiKey: 'test-key',
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('throws for hosted config', () {
      expect(
        () => RealtimeAdapterFactory.create(
          const HostedVoiceAgentApiConfig(modelId: 'hosted-model'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('RealtimeAdapterFactory.testConnection', () {
    test('throws for self-hosted gemini config', () async {
      await expectLater(
        RealtimeAdapterFactory.testConnection(
          const SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.gemini,
            baseUrl: 'https://example.com/v1',
            apiKey: 'test-key',
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('throws for hosted config', () async {
      await expectLater(
        RealtimeAdapterFactory.testConnection(
          const HostedVoiceAgentApiConfig(modelId: 'hosted-model'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
