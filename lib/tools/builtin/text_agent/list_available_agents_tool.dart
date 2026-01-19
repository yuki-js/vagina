import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class ListAvailableAgentsTool extends Tool {
  static const String toolKeyName = 'list_available_agents';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: '利用可能エージェント一覧',
        displayDescription: '利用可能なテキストエージェント一覧を表示します',
        categoryKey: 'text_agent',
        iconKey: 'list',
        sourceKey: 'builtin',
        description:
            'Get a list of all available text agents with their IDs, names, and capabilities.',
        parametersSchema: {
          'type': 'object',
          'properties': {},
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      // Call the text agent API to list agents
      final agents = await context.textAgentApi.listAgents();

      // Return the formatted list
      return jsonEncode({
        'success': true,
        'agents': agents,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to list agents: $e',
      });
    }
  }
}
