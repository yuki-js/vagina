import 'dart:async';
import 'dart:convert';

// Platform-agnostic HTTP client
import 'package:http/http.dart' as http;

/// Abstract API for text agent query operations
///
/// This API allows tools running in isolates to query text agents.
/// All operations are asynchronous and return sendable types (Map, List, primitives).
abstract class TextAgentApi {
  /// Send a query to a text agent
  ///
  /// Arguments:
  /// - agentId: ID of the text agent to query
  /// - prompt: The query prompt
  /// - expectLatency: Expected latency tier ('instant', 'long', 'ultra_long')
  ///
  /// Returns a map with:
  /// - For instant: { "mode": "instant", "text": "...", "agentId": "..." }
  /// - For async: { "mode": "async", "token": "job_...", "agentId": "...", "pollAfterMs": 1500 }
  Future<Map<String, dynamic>> sendQuery(
    String agentId,
    String prompt,
    String expectLatency,
  );

  /// Get the result of an async query by token
  ///
  /// Arguments:
  /// - token: The job token from sendQuery
  ///
  /// Returns a map with status and result/error
  Future<Map<String, dynamic>> getResult(String token);

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
  final Map<String, _AsyncJob> _jobs = {};
  final http.Client _httpClient;
  
  // Tool execution support
  final Future<String> Function(String toolKey, Map<String, dynamic> args)? _executeToolCallback;
  List<Map<String, dynamic>>? _availableTools;

  TextAgentApiClient({
    http.Client? httpClient,
    dynamic initialData,
    Future<String> Function(String, Map<String, dynamic>)? executeToolCallback,
    List<Map<String, dynamic>>? availableTools,
  }) : _httpClient = httpClient ?? http.Client(),
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

  @override
  Future<Map<String, dynamic>> sendQuery(
    String agentId,
    String prompt,
    String expectLatency,
  ) async {
    final agent = _agents[agentId];
    if (agent == null) {
      throw Exception('Agent not found: $agentId');
    }

    if (expectLatency == 'instant') {
      // Execute immediately
      final result = await _executeQuery(agent, prompt, const Duration(seconds: 30));
      return {
        'mode': 'instant',
        'text': result,
        'agentId': agentId,
      };
    } else {
      // Create async job
      final token = _generateJobToken();
      final timeout = expectLatency == 'long'
          ? const Duration(minutes: 10)
          : const Duration(minutes: 60);
      
      final job = _AsyncJob(
        token: token,
        agentId: agentId,
        prompt: prompt,
        timeout: timeout,
      );
      
      _jobs[token] = job;
      
      // Start execution in background (don't await)
      _executeAsyncJob(job, agent);
      
      final pollAfterMs = expectLatency == 'long' ? 1500 : 3000;
      return {
        'mode': 'async',
        'token': token,
        'agentId': agentId,
        'pollAfterMs': pollAfterMs,
      };
    }
  }

  @override
  Future<Map<String, dynamic>> getResult(String token) async {
    final job = _jobs[token];
    if (job == null) {
      throw Exception('Job not found: $token');
    }

    if (job.isCompleted) {
      final result = await job.future;
      return {
        'status': 'succeeded',
        'text': result,
      };
    } else if (job.isFailed) {
      throw Exception('Job failed: ${job.error}');
    } else {
      // Still running
      return {
        'status': 'running',
        'pollAfterMs': 1500,
      };
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
    String prompt,
    Duration timeout,
  ) async {
    // Build URL
    final url = Uri.parse(agent.getEndpointUrl());

    // Build headers
    final headers = agent.getRequestHeaders();

    // Initialize conversation with user message
    final messages = <Map<String, dynamic>>[
      {'role': 'user', 'content': prompt},
    ];

    // Build request body
    final requestBody = <String, dynamic>{
      'messages': messages,
      'max_tokens': 4096,
      'temperature': 1.0,
    };

    // Add model for non-Azure providers
    if (agent.provider != 'azure') {
      requestBody['model'] = agent.getModelIdentifier();
    }

    // Add tools if available
    if (_availableTools != null && _availableTools!.isNotEmpty && _executeToolCallback != null) {
      requestBody['tools'] = _availableTools;
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
          throw Exception('API error (${response.statusCode}): ${response.body}');
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
          messages.add(message);

          // Execute each tool call
          for (final toolCallData in toolCalls) {
            final toolCallId = toolCallData['id'] as String;
            final function = toolCallData['function'] as Map<String, dynamic>;
            final toolName = function['name'] as String;
            final argumentsStr = function['arguments'] as String;

            try {
              // Parse arguments
              final arguments = jsonDecode(argumentsStr) as Map<String, dynamic>;

              // Execute tool via callback
              final result = await _executeToolCallback!(toolName, arguments);

              // Add tool result to conversation
              messages.add({
                'role': 'tool',
                'tool_call_id': toolCallId,
                'name': toolName,
                'content': result,
              });
            } catch (e) {
              // Add error result
              messages.add({
                'role': 'tool',
                'tool_call_id': toolCallId,
                'name': toolName,
                'content': jsonEncode({
                  'success': false,
                  'error': 'Tool execution failed: $e',
                }),
              });
            }
          }

          // Update request with new messages and continue loop
          requestBody['messages'] = messages;
          continue;
        }

        // No tool calls, get final content
        final content = message['content'] as String?;
        if (content == null) {
          throw Exception('No content in response');
        }

        return content;
      }

      // Max turns reached
      throw Exception('Max conversation turns ($maxTurns) reached without completion');
    } on TimeoutException {
      throw Exception('Request timeout after ${timeout.inSeconds}s');
    } catch (e) {
      throw Exception('Query failed: $e');
    }
  }

  /// Execute async job in background
  void _executeAsyncJob(_AsyncJob job, WorkerTextAgent agent) {
    job.future = _executeQuery(agent, job.prompt, job.timeout).then((result) {
      job.isCompleted = true;
      return result;
    }).catchError((error) {
      job.isFailed = true;
      job.error = error.toString();
      throw error;
    });
  }

  String _generateJobToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'job_${timestamp}_$random';
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Internal async job tracker
class _AsyncJob {
  final String token;
  final String agentId;
  final String prompt;
  final Duration timeout;
  
  bool isCompleted = false;
  bool isFailed = false;
  String? error;
  late Future<String> future;

  _AsyncJob({
    required this.token,
    required this.agentId,
    required this.prompt,
    required this.timeout,
  });
}
