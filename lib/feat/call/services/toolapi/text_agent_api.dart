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

  CallTextAgentApi({
    required TextAgentService textAgentService,
  }) : _textAgentService = textAgentService;

  TextAgentService get textAgentService => _textAgentService;

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    final agents = _textAgentService.agents;
    return agents.map((agent) {
      final apiConfig = agent.apiConfig;
      String provider = 'unknown';
      String config = 'Unknown';

      if (apiConfig is SelfhostedTextAgentApiConfig) {
        provider = apiConfig.provider;
        config = '${apiConfig.provider}: ${apiConfig.model}';
      } else if (apiConfig is HostedTextAgentApiConfig) {
        provider = 'hosted';
        config = 'Hosted: ${apiConfig.modelId}';
      }

      return {
        'id': agent.id,
        'name': agent.name,
        'description': agent.description,
        'provider': provider,
        'config': config,
      };
    }).toList();
  }

  @override
  Future<String> sendQuery(String agentId, String prompt) async {
    return _textAgentService.sendQuery(agentId, prompt);
  }
}
