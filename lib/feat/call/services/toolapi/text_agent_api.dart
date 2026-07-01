import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/services/text_agent_service.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

/// Session-scoped text-agent adapter for CallService.
///
/// Implements [TextAgentApi] by delegating to [TextAgentService].
/// This adapter provides a simple delegation layer between tool-facing API
/// and the domain service.
final class CallTextAgentApi implements TextAgentApi {
  final TextAgentService _textAgentService;

  CallTextAgentApi({required TextAgentService textAgentService})
    : _textAgentService = textAgentService;

  TextAgentService get textAgentService => _textAgentService;

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    final agents = _textAgentService.agents;
    final isServiceStarted = _textAgentService.isStarted;
    final hasActiveVoiceSession =
        _textAgentService.currentVoiceSessionId != null;

    return agents
        .map((agent) {
          final apiConfig = agent.apiConfig;
          final textModelId = apiConfig is ServerBackedTextAgentApiConfig
              ? apiConfig.textModelId
              : null;
          final querySupported =
              apiConfig is ServerBackedTextAgentApiConfig &&
              isServiceStarted &&
              hasActiveVoiceSession;
          final queryStatus = switch ((
            apiConfig,
            isServiceStarted,
            hasActiveVoiceSession,
          )) {
            (ServerBackedTextAgentApiConfig _, true, true) => 'ready',
            (ServerBackedTextAgentApiConfig _, false, _) =>
              'Text agent query service is not running.',
            (ServerBackedTextAgentApiConfig _, true, false) =>
              'Text agent query requires an active voice session.',
            _ => 'Text agent query is not available for this agent.',
          };

          return {
            'id': agent.id,
            'name': agent.name,
            'description': agent.description,
            if (textModelId != null) 'text_model_id': textModelId,
            // Backward-compatible field: this is an override map, not the
            // effective catalog. Empty means default-enabled tools minus
            // policy-denied tools, matching sparse Text Agent semantics.
            'enabled_tools': agent.enabledTools,
            'enabled_tool_overrides': agent.enabledTools,
            'effective_tools_default_enabled': true,
            'enabled_tools_semantics':
                'Sparse override map: absent keys are enabled by default; explicit false disables; policy-denied tools remain unavailable.',
            'query_supported': querySupported,
            'query_status': queryStatus,
          };
        })
        .toList(growable: false);
  }

  @override
  Future<String> sendQuery(
    String agentId,
    String prompt, {
    void Function() Function(void Function())? onCancel,
  }) async {
    return _textAgentService.sendQuery(agentId, prompt, onCancel: onCancel);
  }
}
