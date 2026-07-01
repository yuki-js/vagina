import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/services/text_agent_service.dart';
import 'package:vagina/feat/call/services/toolapi/text_agent_api.dart';

import '../text_agent_service_test_support.dart';

void main() {
  group('CallTextAgentApi server-backed definitions', () {
    test(
      'lists server-backed agents without provider runtime details and reflects missing voice session state',
      () async {
        final notepadService = createTestNotepadService();
        final realtimeService = createTestRealtimeService();
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
          notepadService: notepadService,
          realtimeService: realtimeService,
          apiClient: createTestApiClient(_NoopAdapter()),
        );
        await notepadService.start();
        await realtimeService.start();
        await service.start();
        addTearDown(() async {
          await service.dispose();
          await realtimeService.dispose();
          await notepadService.dispose();
        });
        final api = CallTextAgentApi(textAgentService: service);

        final agents = await api.listAgents();

        expect(agents, hasLength(1));
        expect(agents.single, containsPair('text_model_id', 'text-agent-prod'));
        expect(agents.single, containsPair('query_supported', false));
        expect(
          agents.single,
          containsPair(
            'query_status',
            'Text agent query requires an active voice session.',
          ),
        );
        expect(
          agents.single,
          containsPair('enabled_tools', <String, bool>{'list': true}),
        );
        expect(
          agents.single,
          containsPair('enabled_tool_overrides', <String, bool>{'list': true}),
        );
        expect(
          agents.single,
          containsPair('effective_tools_default_enabled', true),
        );
        expect(
          agents.single,
          containsPair(
            'enabled_tools_semantics',
            'Sparse override map: absent keys are enabled by default; explicit false disables; policy-denied tools remain unavailable.',
          ),
        );
        expect(agents.single, isNot(contains('provider')));
        expect(agents.single, isNot(contains('config')));
        expect(agents.single, isNot(contains('apiKey')));
        expect(agents.single, isNot(contains('baseUrl')));
      },
    );

    test(
      'marks server-backed agents unavailable before service start',
      () async {
        final notepadService = createTestNotepadService();
        final realtimeService = createTestRealtimeService(
          sessionId: 'vs_0123456789abcdef',
        );
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
          notepadService: notepadService,
          realtimeService: realtimeService,
          apiClient: createTestApiClient(_NoopAdapter()),
        );
        await notepadService.start();
        await realtimeService.start();
        addTearDown(() async {
          await service.dispose();
          await realtimeService.dispose();
          await notepadService.dispose();
        });
        final api = CallTextAgentApi(textAgentService: service);

        final agents = await api.listAgents();

        expect(agents.single, containsPair('query_supported', false));
        expect(
          agents.single,
          containsPair(
            'query_status',
            'Text agent query service is not running.',
          ),
        );
        expect(agents.single, containsPair('enabled_tools', <String, bool>{}));
        expect(
          agents.single,
          containsPair('enabled_tool_overrides', <String, bool>{}),
        );
        expect(
          agents.single,
          containsPair('effective_tools_default_enabled', true),
        );
      },
    );

    test(
      'marks server-backed agents queryable when a voice session is active',
      () async {
        final notepadService = createTestNotepadService();
        final realtimeService = createTestRealtimeService(
          sessionId: 'vs_0123456789abcdef',
        );
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
          notepadService: notepadService,
          realtimeService: realtimeService,
          apiClient: createTestApiClient(_NoopAdapter()),
        );
        await notepadService.start();
        await realtimeService.start();
        await service.start();
        addTearDown(() async {
          await service.dispose();
          await realtimeService.dispose();
          await notepadService.dispose();
        });
        final api = CallTextAgentApi(textAgentService: service);

        final agents = await api.listAgents();

        expect(agents.single, containsPair('query_supported', true));
        expect(agents.single, containsPair('query_status', 'ready'));
        expect(agents.single, contains('enabled_tool_overrides'));
      },
    );
  });
}

final class _NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw UnimplementedError('HTTP is not used in this test.');
  }

  @override
  void close({bool force = false}) {}
}
