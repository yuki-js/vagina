import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class GetLastTextAgentResponseTool extends Tool {
  static const String toolKeyName = 'get_last_text_agent_response';

  @override
  ToolDefinition get definition => const ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'テキストエージェント非同期結果取得',
    displayDescription: '直近の非同期テキストエージェント結果を取得します',
    categoryKey: 'text_agent',
    iconKey: 'chat',
    sourceKey: 'builtin',
    publishedBy: 'aokiapp',
    description:
        'Get the latest asynchronous text-agent response from this call session. '
        'Use this after say_hello_to_agent reports that a long-running conversation turn has switched to async mode. '
        'No ID is required; this returns the latest async result/status for the current call.',
    parametersSchema: {'type': 'object', 'properties': <String, dynamic>{}},
  );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final result = await context.textAgentApi.pollLastAsyncQueryResult();
    if (result['status'] == 'none') {
      throw StateError('No asynchronous text-agent response is available.');
    }
    return jsonEncode(result);
  }
}
