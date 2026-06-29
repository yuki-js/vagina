import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/services/text_agent_service.dart';
import 'package:vagina/feat/call/services/toolapi/text_agent_api.dart';

void main() {
  group('CallTextAgentApi server-backed definitions', () {
    test(
      'lists server-backed agents without provider runtime details',
      () async {
        final service = TextAgentService(
          agents: const <TextAgentInfo>[
            TextAgentInfo(
              id: 'agent-1',
              name: 'Research Assistant',
              description: 'Looks things up',
              prompt: 'Help with research',
              apiConfig: ServerBackedTextAgentApiConfig(
                textModelId: 'text-agent-prod',
              ),
              enabledTools: <String, bool>{'list': true},
            ),
          ],
        );
        final api = CallTextAgentApi(textAgentService: service);

        final agents = await api.listAgents();

        expect(agents, hasLength(1));
        expect(agents.single, containsPair('text_model_id', 'text-agent-prod'));
        expect(agents.single, containsPair('query_supported', false));
        expect(
          agents.single,
          containsPair('enabled_tools', <String, bool>{'list': true}),
        );
        expect(agents.single, isNot(contains('provider')));
        expect(agents.single, isNot(contains('config')));
        expect(agents.single, isNot(contains('apiKey')));
        expect(agents.single, isNot(contains('baseUrl')));
      },
    );

    test(
      'fails server-backed query with deliberate unsupported message',
      () async {
        final service = TextAgentService(
          agents: const <TextAgentInfo>[
            TextAgentInfo(
              id: 'agent-1',
              name: 'Research Assistant',
              description: 'Looks things up',
              prompt: 'Help with research',
              apiConfig: ServerBackedTextAgentApiConfig(
                textModelId: 'text-agent-prod',
              ),
            ),
          ],
        );
        await service.start();
        addTearDown(service.dispose);

        await expectLater(
          service.sendQuery('agent-1', 'hello'),
          throwsA(
            isA<UnsupportedError>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('query_text_agent is disabled'),
                contains('server-hosted Text Agent execution'),
                contains('agent-1'),
                contains('text-agent-prod'),
              ),
            ),
          ),
        );
      },
    );
  });
}
