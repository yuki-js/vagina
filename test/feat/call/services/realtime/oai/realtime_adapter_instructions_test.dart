import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/oai/fake_oai_transport.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_adapter.dart';
import 'package:vagina/feat/call/services/realtime/oai/realtime_binding.dart';

void main() {
  group('OaiRealtimeAdapter instructions updates', () {
    const config = SelfhostedVoiceAgentApiConfig(
      providerType: VoiceAgentProviderType.openai,
      baseUrl: 'https://fake.openai.test/v1',
      apiKey: 'sk-test',
    );

    late FakeOaiTransport fake;
    late OaiRealtimeClient client;
    late OaiRealtimeAdapter adapter;

    setUp(() {
      fake = FakeOaiTransport();
      client = OaiRealtimeClient(transport: fake);
      adapter = OaiRealtimeAdapter(client: client);
    });

    tearDown(() async {
      await adapter.dispose();
    });

    Map<String, dynamic> sessionOfLastMessage() {
      final message = fake.sentMessages.last;
      expect(message['type'], 'session.update');
      return message['session'] as Map<String, dynamic>;
    }

    test('setInstructions before connect seeds the initial session.update',
        () async {
      await adapter.setInstructions('Initial instructions');
      await adapter.connect(config);
      final initialSession = sessionOfLastMessage();
      expect(initialSession['instructions'], 'Initial instructions');

      await adapter.setInstructions('Updated instructions');
      final updatedSession = sessionOfLastMessage();
      expect(updatedSession['instructions'], 'Updated instructions');
    });

    test('setInstructions with an empty string clears instructions', () async {
      await adapter.setInstructions('Initial instructions');
      await adapter.connect(config);
      final initialSession = sessionOfLastMessage();
      expect(initialSession['instructions'], 'Initial instructions');

      await adapter.setInstructions('');
      final clearedSession = sessionOfLastMessage();
      expect(
        clearedSession,
        containsPair('instructions', ''),
        reason: 'OpenAI Realtime session.update only updates present fields; '
            'string fields such as instructions are cleared with an empty string.',
      );
    });
  });
}
