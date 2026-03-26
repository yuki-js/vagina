import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/text_agent_thread.dart';
import 'package:vagina/feat/callv2/services/transport/text_agent_transport.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// Azure OpenAI Chat Completions transport implementation.
///
/// Converts [TextAgentThread] to Azure-compatible messages format and sends
/// HTTP requests to the Azure Chat Completions API.
class AzureTextAgentTransport implements TextAgentTransport {
  final SelfhostedTextAgentApiConfig _config;
  final http.Client _httpClient;

  AzureTextAgentTransport({
    required SelfhostedTextAgentApiConfig config,
    http.Client? httpClient,
  })  : _config = config,
        _httpClient = httpClient ?? http.Client() {
    if (config.provider != 'azure') {
      throw ArgumentError(
        'AzureTextAgentTransport requires azure provider, got: ${config.provider}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> sendRequest({
    required TextAgentThread thread,
    required String systemPrompt,
    required List<ToolDefinition> availableTools,
  }) async {
    // Build URL
    final url = _buildChatCompletionsUrl();

    // Build headers
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'api-key': _config.apiKey,
    };

    // Convert thread to messages
    final messages = _convertThreadToMessages(thread, systemPrompt);

    // Build request body
    final requestBody = <String, dynamic>{
      'messages': messages,
      'max_completion_tokens': 4096,
      'temperature': 1.0,
    };

    // Convert tool definitions to OpenAI tools format and add if available
    if (availableTools.isNotEmpty) {
      requestBody['tools'] = _convertToolDefinitions(availableTools);
      requestBody['tool_choice'] = 'auto';
    }

    // Send request
    final response = await _httpClient.post(
      url,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Azure API error (${response.statusCode}): ${response.body}',
      );
    }

    // Parse and return response
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
  }

  Uri _buildChatCompletionsUrl() {
    final baseUrl = _config.baseUrl.replaceAll(RegExp(r'/$'), '');

    // Check if baseUrl already contains the full Chat Completions path
    if (baseUrl.toLowerCase().contains('/chat/completions')) {
      return Uri.parse(baseUrl);
    }

    // Build full URL with deployment and API version
    final deployment = _config.params['deployment'] as String? ?? 'default';
    final apiVersion =
        _config.params['apiVersion'] as String? ?? '2024-10-01-preview';

    return Uri.parse(
      '$baseUrl/openai/deployments/$deployment/chat/completions?api-version=$apiVersion',
    );
  }

  List<Map<String, dynamic>> _convertThreadToMessages(
    TextAgentThread thread,
    String systemPrompt,
  ) {
    final messages = <Map<String, dynamic>>[];

    // Check if thread already contains system messages
    final hasSystemInThread = thread.items.any(
      (item) =>
          item.type == TextAgentThreadItemType.message &&
          item.role == TextAgentThreadItemRole.system,
    );

    // Add system prompt first only if not already in thread items
    if (!hasSystemInThread && systemPrompt.trim().isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }

    // Convert each item in order
    for (final item in thread.items) {
      if (item.type == TextAgentThreadItemType.message) {
        messages.add(_convertMessageItem(item));
      } else if (item.type == TextAgentThreadItemType.toolResult) {
        messages.add(_convertToolResultItem(item));
      }
    }

    return messages;
  }

  Map<String, dynamic> _convertMessageItem(TextAgentThreadItem item) {
    final role = _convertRole(item.role);
    final message = <String, dynamic>{'role': role};

    // Add text content if present
    if (item.content.isNotEmpty) {
      final textPart =
          item.findLatestContentPartOfType<TextAgentThreadTextPart>();
      final content = textPart?.text ?? '';
      message['content'] = content;
    }

    // Add tool_calls if present (for assistant messages)
    if (item.toolCalls != null && item.toolCalls!.isNotEmpty) {
      message['tool_calls'] = item.toolCalls!.map((tc) {
        return {
          'id': tc.id,
          'type': 'function',
          'function': {
            'name': tc.name,
            'arguments': tc.arguments,
          },
        };
      }).toList();
    }

    return message;
  }

  Map<String, dynamic> _convertToolResultItem(TextAgentThreadItem item) {
    return {
      'role': 'tool',
      'tool_call_id': item.toolCallId ?? item.id,
      'content': item.toolOutput ?? '',
    };
  }

  String _convertRole(TextAgentThreadItemRole? role) {
    switch (role) {
      case TextAgentThreadItemRole.system:
        return 'system';
      case TextAgentThreadItemRole.user:
        return 'user';
      case TextAgentThreadItemRole.assistant:
        return 'assistant';
      case null:
        return 'user'; // Fallback
    }
  }

  List<Map<String, dynamic>> _convertToolDefinitions(
    List<ToolDefinition> tools,
  ) {
    return tools.map((tool) {
      return {
        'type': 'function',
        'function': {
          'name': tool.toolKey,
          'description': tool.description,
          'parameters': tool.parametersSchema,
        },
      };
    }).toList();
  }
}
