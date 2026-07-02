import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class QueryTextAgentTool extends Tool {
  static const String toolKeyName = 'query_text_agent';
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
        'attach_last_user_image': {
          'type': 'boolean',
          'description':
              'Attach the most recent user image from the current call to this text-agent query. Use this instead of passing image bytes or data URIs in tool arguments.',
        },
      },
      'required': ['agent_id', 'prompt'],
    },
  );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    // Validate parameters
    final agentIdValue = args['agent_id'];
    final promptValue = args['prompt'];

    if (agentIdValue is! String || agentIdValue.isEmpty) {
      throw ArgumentError('Missing or empty required parameter: agent_id');
    }

    if (promptValue is! String || promptValue.trim().isEmpty) {
      throw ArgumentError('Missing or empty required parameter: prompt');
    }

    final attachLastUserImageValue = args['attach_last_user_image'];
    if (attachLastUserImageValue != null && attachLastUserImageValue is! bool) {
      throw ArgumentError(
        'Invalid optional parameter: attach_last_user_image must be a boolean',
      );
    }

    final agentId = agentIdValue;
    final prompt = promptValue;
    final attachLastUserImage = attachLastUserImageValue as bool? ?? false;

    final cancellation = ToolCancellation.current;

    final text = await context.textAgentApi.sendQuery(
      agentId,
      prompt,
      attachLastUserImage: attachLastUserImage,
      onCancel: cancellation?.onCancel,
    );

    return jsonEncode({'success': true, 'text': text});
  }
}
