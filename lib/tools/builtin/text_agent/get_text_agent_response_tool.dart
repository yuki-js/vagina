import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class GetTextAgentResponseTool extends Tool {
  static const String toolKeyName = 'get_text_agent_response';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'テキストエージェントレスポンス取得',
        displayDescription: '非同期クエリの結果を取得します',
        categoryKey: 'text_agent',
        iconKey: 'download',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Retrieve the response from a previously submitted async text agent query using its job token.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'token': {
              'type': 'string',
              'description':
                  'The job token returned from query_text_agent with "long" or "ultra_long" latency',
            },
          },
          'required': ['token'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // Validate parameters
    final token = args['token'] as String?;

    if (token == null || token.isEmpty) {
      return jsonEncode({
        'success': false,
        'error': 'Missing or empty required parameter: token',
      });
    }

    try {
      // Call the text agent API to get result
      final result = await context.textAgentApi.getResult(token);

      // Return the result
      return jsonEncode({
        'success': true,
        ...result,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to get result: $e',
      });
    }
  }
}
