// Tests for RealtimeAdapterFactory.create and .testConnection.
//
// Contract under test:
//   - OAI/OaiCc/Gemini branches are unchanged (regression).
//   - HostedVoiceAgentApiConfig → VhrpRealtimeAdapter is returned (step 9).
//   - The old "not implemented" UnsupportedError for hosted is gone.
//   - testConnection for hosted throws UnsupportedError (no static test-conn
//     method exists on VhrpRealtimeAdapter; live hosted sessions are tested
//     by opening a real VHRP session, not a pre-connect ping).

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/hosted/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/oai_cc/oai_cc_adapter.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter_factory.dart';

void main() {
  // AppContainer must be initialized before RealtimeAdapterFactory.create can
  // be called with HostedVoiceAgentApiConfig, because the hosted branch
  // evaluates AppContainer.auth.getAccessToken at call time.
  setUp(() async {
    AppContainer.reset();
    final store = InMemoryStore();
    await store.initialize();
    await AppContainer.initialize(store: store);
  });

  tearDown(() {
    AppContainer.reset();
  });

  group('RealtimeAdapterFactory.create', () {
    // Contract: OAI self-hosted config → OaiRealtimeAdapter (regression).
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

    // Contract: OAI-CC self-hosted config → OaiCcRealtimeAdapter (regression).
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

    // Contract: Gemini self-hosted config → UnsupportedError (regression).
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

    // Contract: HostedVoiceAgentApiConfig → VhrpRealtimeAdapter is returned
    // and the old "not implemented" UnsupportedError is no longer thrown.
    // tokenProvider is wired to AppContainer.auth.getAccessToken internally.
    test('creates VhrpRealtimeAdapter for hosted config', () {
      final adapter = RealtimeAdapterFactory.create(
        const HostedVoiceAgentApiConfig(modelId: 'vagina-realtime-v1'),
      );

      expect(adapter, isA<VhrpRealtimeAdapter>());
    });

    // Contract: hosted config no longer throws (complementary to above).
    test('does not throw for hosted config', () {
      expect(
        () => RealtimeAdapterFactory.create(
          const HostedVoiceAgentApiConfig(modelId: 'vagina-realtime-v1'),
        ),
        returnsNormally,
      );
    });
  });

  group('RealtimeAdapterFactory.testConnection', () {
    // Contract: Gemini self-hosted still unsupported (regression).
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

    // Contract: hosted testConnection throws UnsupportedError.
    // VhrpRealtimeAdapter has no static test-connection method; a hosted
    // session must be exercised end-to-end via connect(), not a pre-connect
    // ping. The factory correctly surfaces this as UnsupportedError.
    test('throws UnsupportedError for hosted config', () async {
      await expectLater(
        RealtimeAdapterFactory.testConnection(
          const HostedVoiceAgentApiConfig(modelId: 'vagina-realtime-v1'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
