import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:vagina/tools/builtin/call/end_call_tool.dart';
import 'package:vagina/tools/builtin/text_agent/query_text_agent_tool.dart';

/// Session-scoped text-agent domain service for a single CallService session.
final class TextAgentService extends SubService {
  static const int _maxQueryIterations = 20;
  static final Object _queryDepthZoneKey = Object();
  static final Uuid _uuid = Uuid();

  final Map<String, TextAgentInfo> _agentsById = <String, TextAgentInfo>{};
  final NotepadService _notepadService;
  final RealtimeService _realtimeService;
  final VaginaApiClient _apiClient;

  _LastUserImage? _lastUserImage;

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

  /// Remember the latest user-submitted image for semantic text-agent delegation.
  void rememberLastUserImage(Uint8List imageBytes, {String? name}) {
    if (imageBytes.isEmpty) {
      return;
    }
    _lastUserImage = _LastUserImage(Uint8List.fromList(imageBytes), name);
  }

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
    bool attachLastUserImage = false,
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

    final currentQueryDepth = Zone.current[_queryDepthZoneKey];
    if (currentQueryDepth is int && currentQueryDepth > 0) {
      throw StateError('Nested text agent queries are not allowed.');
    }

    return runZoned(() async {
      final requestId = 'req_${_uuid.v4().replaceAll('-', '')}';
      final toolCancellation = ToolCancellation();
      final unregisterCancel = onCancel?.call(toolCancellation.cancel);
      final submittedToolCallIds = <String>{};

      try {
        _throwIfCancelled(toolCancellation);
        var response = await _postQuery(
          agentId: agent.id,
          voiceSessionId: voiceSessionId,
          requestId: requestId,
          prompt: normalizedPrompt,
          images: attachLastUserImage ? _resolvedLastUserImage() : const [],
        );
        _throwIfCancelled(toolCancellation);

        var iterationCount = 0;
        while (iterationCount < _maxQueryIterations) {
          iterationCount += 1;
          response = _validateQueryResponse(response);

          switch (response.status) {
            case TextAgentQueryStatus.completed:
              return response.text!;
            case TextAgentQueryStatus.failed:
              final code = response.errorCode ?? 'unknown_error';
              final message =
                  response.errorMessage ?? 'Text agent query failed.';
              throw Exception('Text agent query failed ($code): $message');
            case TextAgentQueryStatus.requiresTool:
              final nextToolCall = _nextToolCallToSubmit(
                response.toolCalls,
                submittedToolCallIds,
              );
              _throwIfCancelled(toolCancellation);
              final nextToolResult = await _executeToolCall(
                agent,
                nextToolCall,
                cancellation: toolCancellation,
              );
              _throwIfCancelled(toolCancellation);
              submittedToolCallIds.add(nextToolCall.id);
              response = await _postQuery(
                agentId: agent.id,
                voiceSessionId: voiceSessionId,
                requestId: requestId,
                toolResult: nextToolResult,
              );
              _throwIfCancelled(toolCancellation);
          }
        }

        throw Exception(
          'Text agent query exceeded the maximum number of iterations ($_maxQueryIterations).',
        );
      } on DioException catch (error, stackTrace) {
        if (toolCancellation.isCancelled) {
          _throwIfCancelled(toolCancellation);
        }
        logger.severe(
          'Text agent query request failed for agent: $agentId',
          error,
          stackTrace,
        );
        throw Exception(_describeTransportError(error));
      } catch (error, stackTrace) {
        if (toolCancellation.isCancelled) {
          rethrow;
        }
        logger.severe(
          'Text agent query failed for agent: $agentId',
          error,
          stackTrace,
        );
        rethrow;
      } finally {
        unregisterCancel?.call();
      }
    }, zoneValues: <Object, Object>{_queryDepthZoneKey: 1});
  }

  List<ToolDefinition> _getAvailableToolsForAgent(
    TextAgentInfo agent,
    Set<String> activeExtensions,
  ) {
    final extensionFilteredTools = _toolRunner.computeAvailableTools(
      activeExtensions,
    );

    final policyFilteredTools = extensionFilteredTools
        .where((tool) => !_isDeniedNestedTool(tool.toolKey))
        .toList(growable: false);

    if (agent.enabledTools.isEmpty) {
      return policyFilteredTools;
    }

    return policyFilteredTools
        .where((tool) {
          return agent.enabledTools[tool.toolKey] ?? true;
        })
        .toList(growable: false);
  }

  TextAgentQueryResponse _validateQueryResponse(
    TextAgentQueryResponse response,
  ) {
    switch (response.status) {
      case TextAgentQueryStatus.completed:
        if (response.text == null || response.text!.isEmpty) {
          throw Exception(
            'Text agent query returned a malformed completed response: missing text.',
          );
        }
        return response;
      case TextAgentQueryStatus.requiresTool:
        if (response.toolCalls.isEmpty) {
          throw Exception(
            'Text agent query returned a malformed requires_tool response: missing toolCalls.',
          );
        }
        return response;
      case TextAgentQueryStatus.failed:
        return response;
    }
  }

  TextAgentToolCallRequest _nextToolCallToSubmit(
    List<TextAgentToolCallRequest> toolCalls,
    Set<String> submittedToolCallIds,
  ) {
    final seenToolCallIds = <String>{};
    final repeatedSubmittedToolCallIds = <String>{};

    for (final toolCall in toolCalls) {
      if (!seenToolCallIds.add(toolCall.id)) {
        continue;
      }
      if (submittedToolCallIds.contains(toolCall.id)) {
        repeatedSubmittedToolCallIds.add(toolCall.id);
        continue;
      }
      return toolCall;
    }

    if (repeatedSubmittedToolCallIds.isNotEmpty) {
      throw Exception(
        'Text agent repeated already submitted tool call ids: ${repeatedSubmittedToolCallIds.join(', ')}',
      );
    }
    throw Exception(
      'Text agent requested tool execution but no pending tool results remain.',
    );
  }

  Future<TextAgentToolResultSubmission> _executeToolCall(
    TextAgentInfo agent,
    TextAgentToolCallRequest toolCall, {
    required ToolCancellation cancellation,
  }) async {
    if (_isDeniedNestedTool(toolCall.name)) {
      return _toolResultFromError(
        toolCall.id,
        'Tool is not available for nested text agent execution: ${toolCall.name}',
      );
    }

    final availableToolKeys = _getAvailableToolsForAgent(
      agent,
      _getCurrentActiveExtensions(),
    ).map((tool) => tool.toolKey).toSet();
    if (!availableToolKeys.contains(toolCall.name)) {
      return _toolResultFromError(
        toolCall.id,
        'Tool is not available in the current call session: ${toolCall.name}',
      );
    }

    try {
      final output = await _toolRunner.execute(
        toolCall.name,
        toolCall.arguments,
        cancellation: cancellation,
      );
      return _toolResultFromOutput(toolCall.id, output);
    } catch (error, stackTrace) {
      if (cancellation.isCancelled) {
        rethrow;
      }

      logger.severe(
        'Tool execution failed during text agent query: ${toolCall.name}',
        error,
        stackTrace,
      );
      return _toolResultFromError(toolCall.id, 'Tool execution failed: $error');
    }
  }

  void _throwIfCancelled(ToolCancellation cancellation) {
    if (cancellation.isCancelled) {
      throw StateError('Text agent query cancelled.');
    }
  }

  bool _isDeniedNestedTool(String toolKey) {
    return toolKey == QueryTextAgentTool.toolKeyName;
  }

  TextAgentToolResultSubmission _toolResultFromOutput(
    String toolCallId,
    String output,
  ) {
    return TextAgentToolResultSubmission(
      toolCallId: toolCallId,
      output: output,
      isError: _classifyToolOutputAsError(output),
    );
  }

  TextAgentToolResultSubmission _toolResultFromError(
    String toolCallId,
    String message,
  ) {
    return TextAgentToolResultSubmission(
      toolCallId: toolCallId,
      output: jsonEncode(<String, dynamic>{'success': false, 'error': message}),
      isError: true,
    );
  }

  bool _classifyToolOutputAsError(String output) {
    final Object? decoded;
    try {
      decoded = jsonDecode(output);
    } catch (_) {
      // Non-JSON strings are valid tool outputs and are not errors by shape.
      return false;
    }

    if (decoded is Map<String, dynamic>) {
      return _classifyToolOutputMapAsError(decoded);
    }
    if (decoded is Map) {
      return _classifyToolOutputMapAsError(decoded);
    }

    // JSON arrays and primitives are valid tool outputs and are not errors by
    // shape. Tool failures must be signalled by the agreed object conventions
    // below or by throwing.
    return false;
  }

  bool _classifyToolOutputMapAsError(Map<dynamic, dynamic> output) {
    final success = output['success'];
    if (success is bool) {
      return !success;
    }

    final isError = output['isError'];
    if (isError is bool) {
      return isError;
    }

    final error = output['error'];
    return error is String && error.isNotEmpty;
  }

  Future<TextAgentQueryResponse> _postQuery({
    required String agentId,
    required String voiceSessionId,
    required String requestId,
    String? prompt,
    List<api_models.QueryTextAgentBodyImagesItem> images = const [],
    TextAgentToolResultSubmission? toolResult,
  }) async {
    if ((prompt == null) == (toolResult == null)) {
      throw ArgumentError(
        'Exactly one of prompt or toolResult must be provided.',
      );
    }

    final api_responses.QueryTextAgentResponse response;
    try {
      response = await _apiClient.textAgents.queryTextAgent(
        textAgentId: agentId,
        body: api_models.QueryTextAgentBody(
          voiceSessionId: voiceSessionId,
          requestId: requestId,
          prompt: prompt,
          images: images.isEmpty ? null : images,
          // Product intent: Text Agent schemas are supplied by the client because
          // ToolRunner executes client tools. Do not derive this list from VA
          // tools.set or Speed Dial exposed tools; VA and TA allow-lists are
          // intentionally independent so a VA can delegate to a TA with tools
          // unavailable to the VA.
          toolSchemas: _textAgentToolSchemas(),
          toolResult: toolResult?.toGenerated(),
        ),
      );
    } on ArgumentError catch (error) {
      throw Exception(_describeMalformedQueryResponse(error));
    } on TypeError catch (error) {
      throw Exception(_describeMalformedQueryResponse(error));
    } on FormatException catch (error) {
      throw Exception(_describeMalformedQueryResponse(error));
    }

    if (response is api_responses.QueryTextAgentResponseSuccess) {
      return TextAgentQueryResponse.fromGenerated(response.data);
    }

    throw Exception(_describeQueryErrorResponse(response));
  }

  List<api_models.QueryTextAgentBodyImagesItem> _resolvedLastUserImage() {
    final image = _lastUserImage;
    if (image == null) {
      throw StateError('No user image is available to attach.');
    }
    return <api_models.QueryTextAgentBodyImagesItem>[
      api_models.QueryTextAgentBodyImagesItem(
        dataUri: image.dataUri,
        detail: api_models.QueryTextAgentBodyImagesItemDetail.auto,
        name: image.name,
      ),
    ];
  }

  List<api_models.QueryTextAgentBodyToolSchemasItem> _textAgentToolSchemas() {
    return _toolRunner.allDefinitions
        .where((tool) => !_isDeniedTextAgentSchemaTool(tool.toolKey))
        .map(
          (tool) => api_models.QueryTextAgentBodyToolSchemasItem(
            name: tool.toolKey,
            description: tool.description,
            parameters: Map<String, dynamic>.from(
              tool.realtimeParametersSchema,
            ),
          ),
        )
        .toList(growable: false);
  }

  bool _isDeniedTextAgentSchemaTool(String toolKey) {
    return toolKey == QueryTextAgentTool.toolKeyName ||
        toolKey == EndCallTool.toolKeyName;
  }

  String _describeMalformedQueryResponse(Object error) {
    final description = error.toString();
    if (description.contains('status') ||
        (description.contains('supported values') &&
            description.contains('completed') &&
            description.contains('requires_tool') &&
            description.contains('failed'))) {
      return 'Text agent query returned an unknown status.';
    }
    return 'Text agent query returned a malformed response: $description';
  }

  String _describeQueryErrorResponse(
    api_responses.QueryTextAgentResponse response,
  ) {
    if (response is api_responses.QueryTextAgentResponseBadRequest) {
      return 'Text agent query request failed (400): ${_errorResponseMessage(response.data)}';
    }
    if (response is api_responses.QueryTextAgentResponseUnauthorized) {
      return 'Text agent query request failed (401): ${_errorResponseMessage(response.data)}';
    }
    if (response is api_responses.QueryTextAgentResponseNotFound) {
      return 'Text agent query request failed (404): ${_errorResponseMessage(response.data)}';
    }
    if (response is api_responses.QueryTextAgentResponseConflict) {
      return 'Text agent query request failed (409): ${_errorResponseMessage(response.data)}';
    }
    if (response is api_responses.QueryTextAgentResponseServerError) {
      return 'Text agent query request failed (500): ${_errorResponseMessage(response.data)}';
    }
    if (response is api_responses.QueryTextAgentResponseUnknown) {
      return 'Text agent query request failed with status ${response.statusCode}.';
    }
    return 'Text agent query request failed.';
  }

  String _errorResponseMessage(Object data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    final dynamic maybeData = data;
    try {
      final message = maybeData.message;
      if (message is String && message.isNotEmpty) {
        return message;
      }
    } catch (_) {
      // Fall through to string fallback for generated model variants that do not
      // expose a statically visible message getter during partial generation.
    }
    return data.toString();
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

final class _LastUserImage {
  final Uint8List bytes;
  final String? name;

  const _LastUserImage(this.bytes, this.name);

  String get dataUri {
    final mimeType = _sniffImageMime(bytes);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  static String _sniffImageMime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    return 'image/png';
  }
}
