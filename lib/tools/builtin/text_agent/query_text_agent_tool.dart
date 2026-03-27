import 'dart:convert';

import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/services/log_service.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class QueryTextAgentTool extends Tool {
  static const String toolKeyName = 'query_text_agent';

  @override
  Future<Map<String, dynamic>?> loadInitializationData(dynamic config) async {
    if (config is! ConfigRepository) {
      return null;
    }

    try {
      final agents = await config.getAllTextAgents();
      final agentConfigs = agents.map((agent) {
        final apiConfig = agent.apiConfig;
        if (apiConfig is! SelfhostedTextAgentApiConfig) {
          throw UnsupportedError(
            'Only selfhosted text agents are supported: ${agent.id}',
          );
        }
        return {
          'id': agent.id,
          'name': agent.name,
          'description': agent.description,
          'provider': apiConfig.provider,
          'apiKey': apiConfig.apiKey,
          'apiIdentifier': apiConfig.baseUrl,
          'enabledTools': agent.enabledTools,
        };
      }).toList();

      return {'text_agents': agentConfigs};
    } catch (e) {
      LogService()
          .error('QueryTextAgentTool', 'Error loading initialization data: $e');
      return null;
    }
  }

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'テキストエージェントクエリ',
        displayDescription: 'テキストAIエージェントに問い合わせます',
        categoryKey: 'text_agent',
        iconKey: 'chat',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Query a text-based AI agent and return its response text (synchronous, ~30s timeout). '
            'IMPORTANT: Conversation history is maintained per agent_id during the call session. '
            'You can call the same agent multiple times to build on previous responses - '
            'the agent will remember the context of earlier queries in the same call. '
            'Use this for complex tasks that require multiple steps or clarifications.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'agent_id': {
              'type': 'string',
              'description': 'ID of the text agent to query',
            },
            'prompt': {
              'type': 'string',
              'description': 'The query or prompt to send to the agent',
            },
          },
          'required': ['agent_id', 'prompt'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // Validate parameters
    final agentId = args['agent_id'] as String?;
    final prompt = args['prompt'] as String?;

    if (agentId == null || agentId.isEmpty) {
      return jsonEncode({
        'success': false,
        'error': 'Missing or empty required parameter: agent_id',
      });
    }

    if (prompt == null || prompt.trim().isEmpty) {
      return jsonEncode({
        'success': false,
        'error': 'Missing or empty required parameter: prompt',
      });
    }

    try {
      // Call the text agent API
      final text = await context.textAgentApi.sendQuery(
        agentId,
        prompt,
      );

      return jsonEncode({
        'success': true,
        'text': text,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Query failed: $e',
      });
    }
  }
}
