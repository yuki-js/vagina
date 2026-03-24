import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/text_agent_info.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

/// Session-scoped text-agent HTTP client for CallV2.
///
/// This implementation is intentionally minimal:
/// - does not depend on `lib/services/*`
/// - supports one-shot agent listing and query execution
/// - treats hosted agents as explicitly unsupported for now
/// - TODO: implement text-agent tool calling (`tools` / `tool_choice` /
///   `tool_calls`) in this V2 path
final class CallTextAgentApi implements TextAgentApi {
  final Map<String, TextAgentInfo> _agentsById;

  CallTextAgentApi({
    required List<TextAgentInfo> textAgents,
  }) : _agentsById = <String, TextAgentInfo>{
          for (final agent in textAgents) agent.id: agent,
        };

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return _agentsById.values.map(_toAgentListItem).toList(growable: false);
  }

  @override
  Future<String> sendQuery(String agentId, String prompt) async {
    final agent = _agentsById[agentId];
    if (agent == null) {
      throw Exception('Agent not found: $agentId');
    }

    final config = agent.apiConfig;
    if (config is HostedTextAgentApiConfig) {
      throw UnsupportedError(
        'Hosted text agents are not wired to CallV2 yet.',
      );
    }
    if (config is! SelfhostedTextAgentApiConfig) {
      throw UnsupportedError(
        'Unsupported text agent api config for CallV2.',
      );
    }
    if (config.provider != 'azure') {
      throw UnsupportedError(
        'CallV2 only supports Azure OpenAI Service for text agents.',
      );
    }

    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      throw Exception('Prompt must not be empty.');
    }

    // TODO: Support Azure Chat Completions tool calling here by sending
    // `tools` / `tool_choice` and handling the `tool_calls` response loop.
    // Current V2 implementation intentionally supports plain text queries only.
    final baseUrl = config.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final apiVersion =
        (config.params['apiVersion'] as String?) ?? '2024-10-01-preview';
    final deployment = (config.params['deployment'] as String?) ?? config.model;
    final endpointUrl =
        '$baseUrl/openai/deployments/$deployment/chat/completions?api-version=$apiVersion';

    final httpClient = http.Client();
    final response = await httpClient
        .post(
          Uri.parse(endpointUrl),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'api-key': config.apiKey,
          },
          body: jsonEncode(
            <String, dynamic>{
              'messages': <Map<String, String>>[
                <String, String>{
                  'role': 'user',
                  'content': _applyPromptPrefix(agent.prompt, trimmedPrompt),
                },
              ],
            },
          ),
        )
        .timeout(const Duration(seconds: 30));
    httpClient.close();

    if (response.statusCode != 200) {
      throw Exception('API error (${response.statusCode}): ${response.body}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = responseJson['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('No choices in response');
    }

    final message = choices.first['message'];
    if (message is! Map) {
      throw Exception('No message in response');
    }

    final content = message['content'];
    if (content is! String || content.isEmpty) {
      throw Exception('No content in response');
    }

    return content;
  }

  Map<String, dynamic> _toAgentListItem(TextAgentInfo agent) {
    final config = agent.apiConfig;
    final isAzureSelfhosted =
        config is SelfhostedTextAgentApiConfig && config.provider == 'azure';

    return <String, dynamic>{
      'id': agent.id,
      'name': agent.name,
      'description': agent.description,
      'provider': switch (config) {
        SelfhostedTextAgentApiConfig selfhosted => selfhosted.provider,
        HostedTextAgentApiConfig _ => 'hosted',
        _ => 'unknown',
      },
      'config': switch (config) {
        SelfhostedTextAgentApiConfig selfhosted => selfhosted.baseUrl,
        HostedTextAgentApiConfig hosted => 'hosted:${hosted.modelId}',
        _ => '',
      },
      'available': isAzureSelfhosted,
      if (!isAzureSelfhosted)
        'error': 'CallV2 only supports Azure OpenAI Service for text agents.',
    };
  }

  static String _applyPromptPrefix(String agentPrompt, String userPrompt) {
    final normalizedAgentPrompt = agentPrompt.trim();
    if (normalizedAgentPrompt.isEmpty) {
      return userPrompt;
    }

    return <String>[
      normalizedAgentPrompt,
      '',
      userPrompt,
    ].join('\n');
  }
}
