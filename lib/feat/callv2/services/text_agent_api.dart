import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/feat/callv2/services/notepad_service.dart';
import 'package:vagina/feat/callv2/services/text_agent_service.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

/// Session-scoped text-agent adapter for CallV2.
///
/// Implements [TextAgentApi] by delegating to [TextAgentService].
/// This adapter provides the tool-facing API surface while TextAgentService
/// owns the domain logic and thread management.
final class CallTextAgentApi implements TextAgentApi {
  final TextAgentService _textAgentService;
  final NotepadService _notepadService;

  CallTextAgentApi({
    required TextAgentService textAgentService,
    required NotepadService notepadService,
  })  : _textAgentService = textAgentService,
        _notepadService = notepadService;

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
    // Get current active file extensions
    final activeFiles = _notepadService.listActive();
    final activeExtensions = activeFiles
        .map((file) {
          final parts = file.path.split('.');
          return parts.length > 1 ? parts.last.toLowerCase() : '';
        })
        .where((ext) => ext.isNotEmpty)
        .toSet();

    return _textAgentService.sendQuery(
      agentId,
      prompt,
      activeExtensions: activeExtensions,
    );
  }
}
