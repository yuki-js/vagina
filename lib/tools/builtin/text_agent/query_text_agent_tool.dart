import 'dart:convert';

import 'package:vagina/interfaces/config_repository.dart';
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
        return {
          'id': agent.id,
          'name': agent.name,
          'description': agent.description,
          'provider': agent.config.provider.value,
          'apiKey': agent.config.apiKey,
          'apiIdentifier': agent.config.apiIdentifier,
        };
      }).toList();

      return {'text_agents': agentConfigs};
    } catch (e) {
      print('QueryTextAgentTool: Error loading initialization data: $e');
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
            'Query a text-based AI agent for deep reasoning or knowledge. Returns immediate response for "instant" queries, or a job token for "long"/"ultra_long" queries.',
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
            'expect_latency': {
              'type': 'string',
              'enum': ['instant', 'long', 'ultra_long'],
              'description':
                  'Expected response time: "instant" for quick responses (returns result), "long" for deeper reasoning (returns token), "ultra_long" for very complex tasks (returns token)',
            },
          },
          'required': ['agent_id', 'prompt', 'expect_latency'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // Validate parameters
    final agentId = args['agent_id'] as String?;
    final prompt = args['prompt'] as String?;
    final expectLatency = args['expect_latency'] as String?;

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

    if (expectLatency == null) {
      return jsonEncode({
        'success': false,
        'error': 'Missing required parameter: expect_latency',
      });
    }

    // Validate expect_latency value
    if (!['instant', 'long', 'ultra_long'].contains(expectLatency)) {
      return jsonEncode({
        'success': false,
        'error':
            'Invalid expect_latency value. Must be one of: instant, long, ultra_long',
      });
    }

    try {
      // Call the text agent API
      final result = await context.textAgentApi.sendQuery(
        agentId,
        prompt,
        expectLatency,
      );

      // Return the result (format depends on latency mode)
      return jsonEncode({
        'success': true,
        ...result,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Query failed: $e',
      });
    }
  }
}
