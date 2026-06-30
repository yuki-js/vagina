import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:vagina/api/generated/api_models.dart' as api_models;
import 'package:vagina/api/generated/api_responses.dart' as api_responses;
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/call/models/text_agent_query.dart';
import 'package:vagina/feat/call/services/notepad_service.dart';
import 'package:vagina/feat/call/services/realtime_service.dart';
import 'package:vagina/feat/call/services/subservice.dart';
import 'package:vagina/feat/call/services/tool_runner.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// Session-scoped text-agent domain service for a single CallService session.
final class TextAgentService extends SubService {
  static const int _maxQueryIterations = 20;
  static final Uuid _uuid = Uuid();

  final Map<String, TextAgentInfo> _agentsById = <String, TextAgentInfo>{};
  final NotepadService _notepadService;
  final RealtimeService _realtimeService;
  final VaginaApiClient _apiClient;

  late final ToolRunner _toolRunner;

  TextAgentService({
    Iterable<TextAgentInfo> agents = const <TextAgentInfo>[],
    required NotepadService notepadService,
    required RealtimeService realtimeService,
    VaginaApiClient? apiClient,
  }) : _notepadService = notepadService,
       _realtimeService = realtimeService,
       _apiClient = apiClient ?? AppContainer.auth.apiClient {
    _registerAgents(agents);
  }

  /// Read-only view of the text agents available during this call.
  List<TextAgentInfo> get agents =>
      UnmodifiableListView<TextAgentInfo>(_agentsById.values);

  String? get currentVoiceSessionId => _realtimeService.currentSessionId;

  /// Inject ToolRunner for tool execution support.
  ///
  /// Must be called before [start]. Allows breaking circular dependency
  /// between [TextAgentService] and [ToolRunner].
  void setToolRunner(ToolRunner toolRunner) {
    if (isStarted) {
      throw StateError('setToolRunner() must be called before start().');
    }
    _toolRunner = toolRunner;
  }

  /// Get a text agent by id or throw when it is unavailable.
  TextAgentInfo getAgent(String agentId) {
    final agent = _agentsById[agentId];
    if (agent == null) {
      throw StateError('Text agent not found: $agentId');
    }
    return agent;
  }

  /// Send a query to a text agent and return the response.
  ///
  /// Throws [StateError] if the service has not started, the agent is missing,
  /// or there is no active voice session.
  Future<String> sendQuery(
    String agentId,
    String prompt, {
    String? threadId,
    void Function() Function(void Function())? onCancel,
  }) async {
    ensureNotDisposed();
    if (!isStarted) {
      throw StateError('TextAgentService has not been started.');
    }

    final agent = getAgent(agentId);
    final apiConfig = agent.apiConfig;
    if (apiConfig is! ServerBackedTextAgentApiConfig) {
      throw UnsupportedError(
        'Text agent query is not available for agent: ${agent.id}',
      );
    }

    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty) {
      throw ArgumentError.value(prompt, 'prompt', 'Prompt must not be empty.');
    }

    final voiceSessionId = currentVoiceSessionId;
    if (voiceSessionId == null) {
      throw StateError('Text agent query requires an active voice session.');
    }

    final requestId = 'req_${_uuid.v4().replaceAll('-', '')}';
    final toolCancellation = ToolCancellation();
    final unregisterCancel = onCancel?.call(toolCancellation.cancel);
    final preparedToolResults = <String, TextAgentToolResultSubmission>{};
    final pendingToolCallIds = Queue<String>();

    try {
      if (threadId != null && threadId.isNotEmpty) {
        logger.fine('Ignoring text agent threadId for agent ${agent.id}.');
      }

      var response = await _postQuery(
        agentId: agent.id,
        voiceSessionId: voiceSessionId,
        requestId: requestId,
        prompt: normalizedPrompt,
      );

      var iterationCount = 0;
      while (iterationCount < _maxQueryIterations) {
        iterationCount += 1;

        switch (response.status) {
          case TextAgentQueryStatus.completed:
            final text = response.text;
            if (text == null || text.isEmpty) {
              throw Exception(
                'Text agent query completed without returning any text.',
              );
            }
            return text;
          case TextAgentQueryStatus.failed:
            final code = response.errorCode ?? 'unknown_error';
            final message = response.errorMessage ?? 'Text agent query failed.';
            throw Exception('Text agent query failed ($code): $message');
          case TextAgentQueryStatus.requiresTool:
            final toolCalls = response.toolCalls;
            if (toolCalls.isEmpty) {
              throw Exception(
                'Text agent requested tool execution without any tool calls.',
              );
            }

            await _prepareToolResults(
              agent: agent,
              toolCalls: toolCalls,
              preparedToolResults: preparedToolResults,
              cancellation: toolCancellation,
            );
            for (final toolCall in toolCalls) {
              if (pendingToolCallIds.contains(toolCall.id)) {
                continue;
              }
              pendingToolCallIds.add(toolCall.id);
            }

            if (pendingToolCallIds.isEmpty) {
              throw Exception(
                'Text agent requested tool execution but no pending tool results remain.',
              );
            }

            final nextToolCallId = pendingToolCallIds.removeFirst();
            final nextToolResult = preparedToolResults[nextToolCallId];
            if (nextToolResult == null) {
              throw Exception(
                'Text agent requested a tool result that was not prepared: $nextToolCallId',
              );
            }
            response = await _postQuery(
              agentId: agent.id,
              voiceSessionId: voiceSessionId,
              requestId: requestId,
              toolResult: nextToolResult,
            );
        }
      }

      throw Exception(
        'Text agent query exceeded the maximum number of iterations ($_maxQueryIterations).',
      );
    } on DioException catch (error, stackTrace) {
      logger.severe(
        'Text agent query request failed for agent: $agentId',
        error,
        stackTrace,
      );
      throw Exception(_describeTransportError(error));
    } catch (error, stackTrace) {
      logger.severe(
        'Text agent query failed for agent: $agentId',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      unregisterCancel?.call();
    }
  }

  List<ToolDefinition> _getAvailableToolsForAgent(
    TextAgentInfo agent,
    Set<String> activeExtensions,
  ) {
    final extensionFilteredTools = _toolRunner.computeAvailableTools(
      activeExtensions,
    );

    if (agent.enabledTools.isEmpty) {
      return extensionFilteredTools;
    }

    return extensionFilteredTools
        .where((tool) {
          return agent.enabledTools[tool.toolKey] ?? true;
        })
        .toList(growable: false);
  }

  Future<void> _prepareToolResults({
    required TextAgentInfo agent,
    required List<TextAgentToolCallRequest> toolCalls,
    required Map<String, TextAgentToolResultSubmission> preparedToolResults,
    required ToolCancellation cancellation,
  }) async {
    final availableToolKeys = _getAvailableToolsForAgent(
      agent,
      _getCurrentActiveExtensions(),
    ).map((tool) => tool.toolKey).toSet();

    for (final toolCall in toolCalls) {
      if (preparedToolResults.containsKey(toolCall.id)) {
        continue;
      }

      preparedToolResults[toolCall.id] = await _executeToolCall(
        toolCall,
        availableToolKeys: availableToolKeys,
        cancellation: cancellation,
      );
    }
  }

  Future<TextAgentToolResultSubmission> _executeToolCall(
    TextAgentToolCallRequest toolCall, {
    required Set<String> availableToolKeys,
    required ToolCancellation cancellation,
  }) async {
    if (!availableToolKeys.contains(toolCall.name)) {
      return TextAgentToolResultSubmission(
        toolCallId: toolCall.id,
        output: jsonEncode(<String, dynamic>{
          'success': false,
          'error':
              'Tool is not available in the current call session: ${toolCall.name}',
        }),
        isError: true,
      );
    }

    try {
      final output = await _toolRunner.execute(
        toolCall.name,
        toolCall.arguments,
        cancellation: cancellation,
      );
      return TextAgentToolResultSubmission(
        toolCallId: toolCall.id,
        output: output,
        isError: _isToolOutputError(output),
      );
    } catch (error, stackTrace) {
      if (cancellation.isCancelled) {
        rethrow;
      }

      logger.severe(
        'Tool execution failed during text agent query: ${toolCall.name}',
        error,
        stackTrace,
      );
      return TextAgentToolResultSubmission(
        toolCallId: toolCall.id,
        output: jsonEncode(<String, dynamic>{
          'success': false,
          'error': 'Tool execution failed: $error',
        }),
        isError: true,
      );
    }
  }

  bool _isToolOutputError(String output) {
    try {
      final decoded = jsonDecode(output);
      if (decoded is Map<String, dynamic>) {
        final success = decoded['success'];
        return success is bool && success == false;
      }
      if (decoded is Map) {
        final success = decoded['success'];
        return success is bool && success == false;
      }
    } catch (_) {
      // Ignore malformed tool output and rely on thrown exceptions instead.
    }
    return false;
  }

  Future<TextAgentQueryResponse> _postQuery({
    required String agentId,
    required String voiceSessionId,
    required String requestId,
    String? prompt,
    TextAgentToolResultSubmission? toolResult,
  }) async {
    if ((prompt == null) == (toolResult == null)) {
      throw ArgumentError(
        'Exactly one of prompt or toolResult must be provided.',
      );
    }

    final response = await _apiClient.textAgents.queryTextAgent(
      textAgentId: agentId,
      body: api_models.QueryTextAgentBody(
        voiceSessionId: voiceSessionId,
        requestId: requestId,
        prompt: prompt,
        toolResult: toolResult?.toGenerated(),
      ),
    );

    if (response is api_responses.QueryTextAgentResponseSuccess) {
      return TextAgentQueryResponse.fromGenerated(response.data);
    }

    throw Exception(_describeQueryErrorResponse(response));
  }

  String _describeQueryErrorResponse(
    api_responses.QueryTextAgentResponse response,
  ) {
    if (response is api_responses.QueryTextAgentResponseBadRequest) {
      return 'Text agent query request failed (400): ${response.data.message}';
    }
    if (response is api_responses.QueryTextAgentResponseUnauthorized) {
      return 'Text agent query request failed (401): ${response.data.message}';
    }
    if (response is api_responses.QueryTextAgentResponseNotFound) {
      return 'Text agent query request failed (404): ${response.data.message}';
    }
    if (response is api_responses.QueryTextAgentResponseConflict) {
      return 'Text agent query request failed (409): ${response.data.message}';
    }
    if (response is api_responses.QueryTextAgentResponseServerError) {
      return 'Text agent query request failed (500): ${response.data.message}';
    }
    if (response is api_responses.QueryTextAgentResponseUnknown) {
      return 'Text agent query request failed with status ${response.statusCode}.';
    }
    return 'Text agent query request failed.';
  }

  String _describeTransportError(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    String? message;

    if (responseData is Map) {
      final body = Map<String, dynamic>.from(responseData);
      final directMessage = body['message'];
      if (directMessage is String && directMessage.isNotEmpty) {
        message = directMessage;
      } else {
        final nestedError = body['error'];
        if (nestedError is Map) {
          final nestedMessage = nestedError['message'];
          if (nestedMessage is String && nestedMessage.isNotEmpty) {
            message = nestedMessage;
          }
        }
      }
    }

    if (statusCode != null && message != null) {
      return 'Text agent query request failed ($statusCode): $message';
    }
    if (statusCode != null) {
      return 'Text agent query request failed with status $statusCode.';
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return 'Text agent query request failed: ${error.message}';
    }
    return 'Text agent query request failed.';
  }

  void _registerAgents(Iterable<TextAgentInfo> agents) {
    for (final agent in agents) {
      final existing = _agentsById[agent.id];
      if (existing != null) {
        throw ArgumentError.value(
          agent.id,
          'agents',
          'Duplicate text agent id: ${agent.id}',
        );
      }
      _agentsById[agent.id] = agent;
    }
  }

  Set<String> _getCurrentActiveExtensions() {
    final activeFiles = _notepadService.listActive();
    return activeFiles
        .map((file) => file.extension.toLowerCase())
        .where((ext) => ext.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    _agentsById.clear();
  }
}
