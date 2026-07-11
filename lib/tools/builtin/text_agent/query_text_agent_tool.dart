import 'dart:async';
import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class QueryTextAgentTool extends Tool {
  static const String toolKeyName = 'say_hello_to_agent';
  static const Duration defaultAsyncFallbackDelay = Duration(seconds: 20);

  final Duration asyncFallbackDelay;

  QueryTextAgentTool({this.asyncFallbackDelay = defaultAsyncFallbackDelay});

  @override
  ToolDefinition get definition => const ToolDefinition(
    toolKey: toolKeyName,
    displayName: 'エージェントと会話',
    displayDescription: 'テキストAIエージェントに話しかけ、会話を続けます',
    categoryKey: 'text_agent',
    iconKey: 'chat',
    sourceKey: 'builtin',
    publishedBy: 'aokiapp',
    description:
        'Start or continue a conversation with a text-based AI agent and return what it says. '
        'Speak naturally and treat the agent as a conversation partner, not as a stateless query processor. '
        'If the conversation turn is still running after about 20 seconds, this tool returns an async-mode notice; call get_last_text_agent_response later to retrieve the latest reply. '
        'You can talk to the same agent multiple times to build on previous turns, and the agent will remember the context of earlier conversation in the same call. '
        'You are encourage to talk multiple turns for refinement of answer, complex tasks, clarification, and collaborative thinking.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'agent_id': {
          'type': 'string',
          'description': 'ID of the text agent to talk to',
        },
        'prompt': {
          'type': 'string',
          'description': 'What to say to the agent in this conversation turn',
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

    final query = context.textAgentApi.sendQuery(
      agentId,
      prompt,
      attachLastUserImage: attachLastUserImage,
      onCancel: cancellation?.onCancel,
    );

    try {
      final text = await query.timeout(asyncFallbackDelay);
      return jsonEncode({'success': true, 'text': text});
    } on TimeoutException {
      final pendingResult = <String, dynamic>{
        'status': 'pending',
        'agent_id': agentId,
      };
      await context.textAgentApi.setLastAsyncQueryResult(pendingResult);
      unawaited(
        query
            .then((text) {
              return context.textAgentApi.setLastAsyncQueryResult(
                <String, dynamic>{
                  'status': 'completed',
                  'agent_id': agentId,
                  'success': true,
                  'text': text,
                },
              );
            })
            .catchError((Object error) {
              return context.textAgentApi
                  .setLastAsyncQueryResult(<String, dynamic>{
                    'status': 'failed',
                    'agent_id': agentId,
                    'success': false,
                    'error': error.toString(),
                  });
            }),
      );
      return jsonEncode(<String, dynamic>{
        'success': true,
        'async': true,
        ...pendingResult,
        'message':
            'The text agent query is still running asynchronously. Wait for user answer and call get_last_text_agent_response later for the next time.',
      });
    }
  }
}
