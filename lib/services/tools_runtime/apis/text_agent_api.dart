import 'dart:async';
import 'dart:convert';

// Platform-agnostic HTTP client
import 'package:http/http.dart' as http;

import 'package:vagina/feat/call/models/text_agent_thread.dart';

/// Abstract API for text agent query operations
///
/// This API allows tools running in isolates to query text agents.
/// All operations are asynchronous and return sendable types (Map, List, primitives).
abstract class TextAgentApi {
  /// Send a query to a text agent and return the response text.
  ///
  /// Sends a query and returns the response text with a fixed 30 second timeout.
  Future<String> sendQuery(
    String agentId,
    String prompt,
  );

  /// List all available text agents
  ///
  /// Returns a list of agent metadata maps
  Future<List<Map<String, dynamic>>> listAgents();
}

/// Simplified agent data for worker-side execution
class WorkerTextAgent {
  final String id;
  final String name;
  final String? description;
  final String provider;
  final String apiKey;
  final String apiIdentifier;

  WorkerTextAgent({
    required this.id,
    required this.name,
    this.description,
    required this.provider,
    required this.apiKey,
    required this.apiIdentifier,
  });

  factory WorkerTextAgent.fromJson(Map<String, dynamic> json) {
    return WorkerTextAgent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      provider: json['provider'] as String,
      apiKey: json['apiKey'] as String,
      apiIdentifier: json['apiIdentifier'] as String,
    );
  }

  /// Get the API endpoint URL
  String getEndpointUrl() {
    switch (provider) {
      case 'openai':
        return 'https://api.openai.com/v1/chat/completions';
      case 'azure':
        final trimmed = apiIdentifier.trim();
        if (_looksLikeAzureChatCompletionsUrl(trimmed)) {
          return trimmed;
        }
        final base = trimmed.replaceAll(RegExp(r'/$'), '');
        return '$base/openai/deployments/default/chat/completions?api-version=2024-10-01-preview';
      case 'litellm':
        return '${apiIdentifier.replaceAll(RegExp(r'/$'), '')}/chat/completions';
      case 'custom':
        return '${apiIdentifier.replaceAll(RegExp(r'/$'), '')}/chat/completions';
      default:
        return 'https://api.openai.com/v1/chat/completions';
    }
  }

  /// Get the model identifier
  String getModelIdentifier() {
    switch (provider) {
      case 'openai':
        return apiIdentifier;
      case 'azure':
        return _tryExtractAzureDeploymentFromUrl(apiIdentifier) ?? 'gpt-4o';
      default:
        return 'gpt-4o';
    }
  }

  /// Get request headers
  Map<String, String> getRequestHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    switch (provider) {
      case 'openai':
        headers['Authorization'] = 'Bearer $apiKey';
        break;
      case 'azure':
        headers['api-key'] = apiKey;
        break;
      case 'litellm':
        headers['Authorization'] = 'Bearer $apiKey';
        break;
      case 'custom':
        headers['Authorization'] = 'Bearer $apiKey';
        headers['api-key'] = apiKey;
        break;
    }

    return headers;
  }

  static bool _looksLikeAzureChatCompletionsUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);

    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      final lower = trimmed.toLowerCase();
      final hasHttpScheme =
          lower.startsWith('https://') || lower.startsWith('http://');
      return hasHttpScheme &&
          lower.contains('/openai/deployments/') &&
          lower.contains('/chat/completions');
    }

    final path = uri.path.toLowerCase();
    return path.contains('/openai/deployments/') &&
        path.contains('/chat/completions');
  }

  static String? _tryExtractAzureDeploymentFromUrl(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);

    final path = uri?.path ?? trimmed.split('?').first;

    final match = RegExp(
      r'/openai/deployments/([^/]+)/',
      caseSensitive: false,
    ).firstMatch(path);

    return match?.group(1);
  }
}

/// Client implementation that executes HTTP requests directly in the worker isolate
class TextAgentApiClient implements TextAgentApi {
  final Map<String, WorkerTextAgent> _agents = {};
  final http.Client _httpClient;

  // Tool execution support
  final Future<String> Function(String toolKey, Map<String, dynamic> args)?
      _executeToolCallback;
  List<Map<String, dynamic>>? _availableTools;

  // Per-agent tool filtering configuration
  final Map<String, Map<String, bool>> _agentToolConfigs = {};

  // Conversation threads (one per agent, persists during isolate lifetime)
  final Map<String, TextAgentThread> _threads = {};

  TextAgentApiClient({
    http.Client? httpClient,
    dynamic initialData,
    Future<String> Function(String, Map<String, dynamic>)? executeToolCallback,
    List<Map<String, dynamic>>? availableTools,
  })  : _httpClient = httpClient ?? http.Client(),
        _executeToolCallback = executeToolCallback,
        _availableTools = availableTools ?? [] {
    // Initialize agents if provided
    if (initialData is List) {
      try {
        final configs = initialData
            .cast<Map<String, dynamic>>()
            .map((json) => WorkerTextAgent.fromJson(json))
            .toList();
        _initializeAgents(configs);
      } catch (e) {
        // Initialization error - log but don't throw
        // This allows the client to be created even if initial data is invalid
      }
    }
  }

  /// Initialize agent configurations
  void _initializeAgents(List<WorkerTextAgent> agents) {
    _agents.clear();
    for (final agent in agents) {
      _agents[agent.id] = agent;
    }
  }

  /// Update agent configurations (for external updates)
  void updateAgents(List<WorkerTextAgent> agents) {
    _initializeAgents(agents);
  }

  /// Update available tools for tool calling
  void updateTools(List<Map<String, dynamic>> tools) {
    _availableTools = tools;
  }

  /// Update agent-specific tool configuration
  void updateAgentTools(String agentId, Map<String, bool> toolConfig) {
    _agentToolConfigs[agentId] = toolConfig;
  }

  /// Get filtered tools for a specific agent
  List<Map<String, dynamic>> _getToolsForAgent(String agentId) {
    final agentConfig = _agentToolConfigs[agentId];
    if (agentConfig == null || agentConfig.isEmpty) {
      return _availableTools ?? []; // No config => all tools enabled
    }
    return (_availableTools ?? []).where((tool) {
      final toolKey = tool['function']['name'] as String;
      return agentConfig[toolKey] ?? true; // Key absent = true
    }).toList();
  }

  @override
  Future<String> sendQuery(
    String agentId,
    String prompt,
  ) async {
    final agent = _agents[agentId];
    if (agent == null) {
      throw Exception('Agent not found: $agentId');
    }

    // Get or create conversation thread for this agent
    final thread = _threads.putIfAbsent(
      agentId,
      () => TextAgentThread(id: 'thread_$agentId'),
    );

    // Add user message to thread
    _addUserMessage(thread, prompt);

    try {
      // Execute query with 30-second timeout
      return await _executeQuery(agent, thread, const Duration(seconds: 30));
    } catch (e) {
      // Handle context length errors with automatic retry
      if (_isContextLengthError(e) && thread.length > 0) {
        // Calculate how many messages to trim (approximately 25%)
        final trimCount = (thread.length * 0.25).ceil().clamp(1, 10);

        // Remove oldest messages
        thread.trimLeadingItems(trimCount);

        // Re-add the current user message (it was removed by trimming)
        _addUserMessage(thread, prompt);

        // Retry once with reduced history
        return await _executeQuery(agent, thread, const Duration(seconds: 30));
      }

      // Re-throw if not a context length error or retry failed
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    return _agents.values.map((agent) {
      return {
        'id': agent.id,
        'name': agent.name,
        'description': agent.description ?? '',
        'provider': agent.provider,
        'config': '${agent.provider}:${agent.apiIdentifier}',
      };
    }).toList();
  }

  /// Execute HTTP query to the agent with tool calling support
  Future<String> _executeQuery(
    WorkerTextAgent agent,
    TextAgentThread thread,
    Duration timeout,
  ) async {
    // Build URL
    final url = Uri.parse(agent.getEndpointUrl());

    // Build headers
    final headers = agent.getRequestHeaders();

    // Build request body with conversation history
    final requestBody = <String, dynamic>{
      'messages': _threadToMessages(thread),
    };

    // Add model for non-Azure providers
    if (agent.provider != 'azure') {
      requestBody['model'] = agent.getModelIdentifier();
    }

    // Add tools if available (filtered per agent)
    final agentTools = _getToolsForAgent(agent.id);
    if (agentTools.isNotEmpty && _executeToolCallback != null) {
      requestBody['tools'] = agentTools;
      requestBody['tool_choice'] = 'auto';
    }

    // Multi-turn conversation loop for tool calling
    int turnCount = 0;
    const maxTurns = 10; // Prevent infinite loops

    try {
      while (turnCount < maxTurns) {
        turnCount++;

        final response = await _httpClient
            .post(
              url,
              headers: headers,
              body: jsonEncode(requestBody),
            )
            .timeout(timeout);

        if (response.statusCode != 200) {
          throw Exception(
              'API error (${response.statusCode}): ${response.body}');
        }

        final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = responseJson['choices'] as List?;

        if (choices == null || choices.isEmpty) {
          throw Exception('No choices in response');
        }

        final message = choices[0]['message'] as Map<String, dynamic>?;
        if (message == null) {
          throw Exception('No message in response');
        }

        // Check if the response contains tool calls
        final toolCalls = message['tool_calls'] as List?;

        if (toolCalls != null && toolCalls.isNotEmpty) {
          // AI wants to call tools
          // Add assistant message with tool calls to conversation
          _addAssistantMessage(thread, message);

          // Execute each tool call
          for (final toolCallData in toolCalls) {
            final toolCallId = toolCallData['id'] as String;
            final function = toolCallData['function'] as Map<String, dynamic>;
            final toolName = function['name'] as String;
            final argumentsStr = function['arguments'] as String;

            try {
              // Parse arguments
              final arguments =
                  jsonDecode(argumentsStr) as Map<String, dynamic>;

              // Execute tool via callback
              final result = await _executeToolCallback!(toolName, arguments);

              // Add tool result to conversation thread
              _addToolResult(thread, toolCallId, toolName, result);
            } catch (e) {
              // Add error result to thread
              _addToolResult(
                thread,
                toolCallId,
                toolName,
                jsonEncode({
                  'success': false,
                  'error': 'Tool execution failed: $e',
                }),
              );
            }
          }

          // Update request with updated thread messages and continue loop
          requestBody['messages'] = _threadToMessages(thread);
          continue;
        }

        // No tool calls, get final content
        final content = message['content'] as String?;
        if (content == null) {
          throw Exception('No content in response');
        }

        // Add final assistant message to thread
        _addAssistantMessage(thread, message);

        return content;
      }

      // Max turns reached
      throw Exception(
          'Max conversation turns ($maxTurns) reached without completion');
    } on TimeoutException {
      throw Exception('Request timeout after ${timeout.inSeconds}s');
    } catch (e) {
      throw Exception('Query failed: $e');
    }
  }

  /// Check if an error is related to context length limits
  bool _isContextLengthError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('context_length_exceeded') ||
        errorStr.contains('context length') ||
        errorStr.contains('maximum context') ||
        errorStr.contains('token limit') ||
        errorStr.contains('tokens exceeded');
  }

  /// Add user message to thread
  void _addUserMessage(TextAgentThread thread, String content) {
    final item = TextAgentThreadItem(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      type: TextAgentThreadItemType.message,
      role: TextAgentThreadItemRole.user,
      status: TextAgentThreadItemStatus.completed,
    );
    final textPart = TextAgentThreadTextPart(text: content, isDone: true);
    item.addContentPart(textPart);
    thread.addItem(item);
  }

  /// Add assistant message to thread
  void _addAssistantMessage(
    TextAgentThread thread,
    Map<String, dynamic> message,
  ) {
    final item = TextAgentThreadItem(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      type: TextAgentThreadItemType.message,
      role: TextAgentThreadItemRole.assistant,
      status: TextAgentThreadItemStatus.completed,
    );

    // Add text content if present
    final content = message['content'] as String?;
    if (content != null && content.isNotEmpty) {
      final textPart = TextAgentThreadTextPart(text: content, isDone: true);
      item.addContentPart(textPart);
    }

    // Add tool calls if present
    final toolCalls = message['tool_calls'] as List?;
    if (toolCalls != null && toolCalls.isNotEmpty) {
      item.toolCalls = toolCalls
          .map((tc) => TextAgentToolCall(
                id: tc['id'] as String,
                name: (tc['function'] as Map<String, dynamic>)['name'] as String,
                arguments: (tc['function'] as Map<String, dynamic>)['arguments']
                    as String,
              ))
          .toList();
    }

    thread.addItem(item);
  }

  /// Add tool result to thread
  void _addToolResult(
    TextAgentThread thread,
    String toolCallId,
    String toolName,
    String output,
  ) {
    final item = TextAgentThreadItem(
      id: 'toolresult_${DateTime.now().millisecondsSinceEpoch}',
      type: TextAgentThreadItemType.toolResult,
      status: TextAgentThreadItemStatus.completed,
      toolCallId: toolCallId,
      toolName: toolName,
      toolOutput: output,
    );
    thread.addItem(item);
  }

  /// Convert thread to Chat Completions messages format
  List<Map<String, dynamic>> _threadToMessages(TextAgentThread thread) {
    final messages = <Map<String, dynamic>>[];

    for (final item in thread.items) {
      if (item.type == TextAgentThreadItemType.message) {
        final message = <String, dynamic>{
          'role': item.role!.name,
        };

        // Add text content
        final textParts = item.content.whereType<TextAgentThreadTextPart>();
        if (textParts.isNotEmpty) {
          message['content'] = textParts.first.text;
        }

        // Add tool calls if present (assistant messages only)
        if (item.toolCalls != null && item.toolCalls!.isNotEmpty) {
          message['tool_calls'] = item.toolCalls!
              .map((tc) => {
                    'id': tc.id,
                    'type': 'function',
                    'function': {
                      'name': tc.name,
                      'arguments': tc.arguments,
                    },
                  })
              .toList();
        }

        messages.add(message);
      } else if (item.type == TextAgentThreadItemType.toolResult) {
        // Tool result item
        messages.add({
          'role': 'tool',
          'tool_call_id': item.toolCallId!,
          'content': item.toolOutput!,
        });
      }
    }

    return messages;
  }

  void dispose() {
    _threads.clear();
    _httpClient.close();
  }
}
