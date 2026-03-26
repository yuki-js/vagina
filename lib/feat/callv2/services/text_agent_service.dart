import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/text_agent_info.dart';
import 'package:vagina/feat/callv2/models/text_agent_thread.dart';
import 'package:vagina/feat/callv2/services/transport/text_agent_transport.dart';
import 'package:vagina/feat/callv2/services/transport/text_agent_transport_azure.dart';
import 'package:vagina/feat/callv2/services/notepad_service.dart';
import 'package:vagina/feat/callv2/services/subservice.dart';
import 'package:vagina/feat/callv2/services/tool_runner.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// Session-scoped text-agent domain service for a single CallV2 session.
///
/// Owns the text agent registry, thread management, and query execution.
/// Delegates HTTP transport to provider-specific [TextAgentTransport] implementations.
final class TextAgentService extends SubService {
  static const String _defaultThreadId = 'default';

  final Map<String, TextAgentInfo> _agentsById = <String, TextAgentInfo>{};

  /// Thread storage: agentId → threadId → thread.
  /// Currently uses threadId='default' for single-thread-per-agent.
  final Map<String, Map<String, TextAgentThread>> _threadsByAgent =
      <String, Map<String, TextAgentThread>>{};

  NotepadService? _notepadService;
  ToolRunner? _toolRunner;

  TextAgentService({
    Iterable<TextAgentInfo> agents = const <TextAgentInfo>[],
  }) {
    _registerAgents(agents);
  }

  /// Inject NotepadService for dynamic active file tracking.
  ///
  /// Must be called before [start]. Required for dynamic tool filtering.
  void setNotepadService(NotepadService notepadService) {
    if (isStarted) {
      logger.warning('Attempt to set NotepadService after service started');
      throw StateError('setNotepadService() must be called before start().');
    }
    logger.fine('NotepadService injected');
    _notepadService = notepadService;
  }

  /// Read-only view of the text agents available during this call.
  List<TextAgentInfo> get agents =>
      UnmodifiableListView<TextAgentInfo>(_agentsById.values);

  /// Find a text agent by id.
  TextAgentInfo? findAgent(String agentId) => _agentsById[agentId];

  /// Get a text agent by id or throw when it is unavailable.
  TextAgentInfo getAgent(String agentId) {
    final agent = findAgent(agentId);
    if (agent == null) {
      throw StateError('Text agent not found: $agentId');
    }
    return agent;
  }

  /// Inject ToolRunner for tool execution support.
  ///
  /// Must be called before [start]. Allows breaking circular dependency
  /// between [TextAgentService] and [ToolRunner].
  void setToolRunner(ToolRunner toolRunner) {
    if (isStarted) {
      logger.warning('Attempt to set ToolRunner after service started');
      throw StateError('setToolRunner() must be called before start().');
    }
    logger.fine('ToolRunner injected');
    _toolRunner = toolRunner;
  }

  /// Get or create a thread for the given agent.
  ///
  /// Currently uses a single 'default' thread per agent. Future support for
  /// multiple threads per agent can be added by passing a threadId parameter.
  TextAgentThread getOrCreateThread(String agentId, {String? threadId}) {
    final effectiveThreadId = threadId ?? _defaultThreadId;

    final agentThreads = _threadsByAgent.putIfAbsent(
      agentId,
      () => <String, TextAgentThread>{},
    );

    return agentThreads.putIfAbsent(
      effectiveThreadId,
      () => TextAgentThread(
        id: '${agentId}_$effectiveThreadId',
      ),
    );
  }

  /// Find a thread for the given agent (returns null if not exists).
  TextAgentThread? findThread(String agentId, {String? threadId}) {
    final effectiveThreadId = threadId ?? _defaultThreadId;
    return _threadsByAgent[agentId]?[effectiveThreadId];
  }

  /// Send a query to a text agent and return the response.
  ///
  /// Maintains conversation history in the agent's thread. Supports tool calling
  /// via the configured [ToolRunner].
  ///
  /// Throws [StateError] if agent not found or service not started.
  /// Throws [Exception] on API errors or tool execution failures.
  Future<String> sendQuery(
    String agentId,
    String prompt, {
    String? threadId,
  }) async {
    if (!isStarted) {
      logger.severe('Attempt to send query before service started');
      throw StateError('TextAgentService has not been started.');
    }

    logger.info('Sending query to agent: $agentId (${prompt.length} chars)');
    logger.fine('Query prompt: ${prompt.length > 100 ? "${prompt.substring(0, 100)}..." : prompt}');

    // Get agent
    final agent = getAgent(agentId);

    // Get or create thread
    final thread = getOrCreateThread(agentId, threadId: threadId);
    logger.fine('Using thread: ${thread.id} (${thread.length} items)');

    // Add user message to thread
    final userItem = TextAgentThreadItem(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      type: TextAgentThreadItemType.message,
      role: TextAgentThreadItemRole.user,
      status: TextAgentThreadItemStatus.completed,
      content: [TextAgentThreadTextPart(text: prompt, isDone: true)],
    );
    thread.addItem(userItem);

    // Create transport
    final transport = _createTransport(agent);

    try {
      // Execute query with tool calling support
      final result = await _executeQueryLoop(
        agent: agent,
        thread: thread,
        transport: transport,
      );

      logger.info('Query completed successfully (response: ${result.length} chars)');
      return result;
    } catch (e, stackTrace) {
      // Check for context length errors and retry
      if (_isContextLengthError(e) && thread.length > 0) {
        // Trim ~25% of oldest items
        final trimCount = (thread.length * 0.25).ceil().clamp(1, 10);
        logger.warning(
            'Context length error detected, trimming $trimCount items from thread (${thread.length} → ${thread.length - trimCount})');
        thread.trimLeadingItems(trimCount);

        // Re-add user message
        thread.addItem(userItem);

        logger.info('Retrying query after context trimming');
        // Retry once
        return await _executeQueryLoop(
          agent: agent,
          thread: thread,
          transport: transport,
        );
      }

      logger.severe('Query failed for agent: $agentId', e, stackTrace);
      rethrow;
    } finally {
      await transport.dispose();
    }
  }

  TextAgentTransport _createTransport(TextAgentInfo agent) {
    final apiConfig = agent.apiConfig;

    logger.fine('Creating transport for agent: ${agent.id}, config type: ${apiConfig.runtimeType}');

    if (apiConfig is SelfhostedTextAgentApiConfig) {
      if (apiConfig.provider == 'azure') {
        logger.fine('Using Azure transport');
        return AzureTextAgentTransport(config: apiConfig);
      }
      logger.warning('Unsupported provider: ${apiConfig.provider}');
      throw UnsupportedError(
        'Provider not supported yet: ${apiConfig.provider}',
      );
    }

    if (apiConfig is HostedTextAgentApiConfig) {
      logger.warning('Hosted text agents not supported yet');
      throw UnsupportedError('Hosted text agents not supported yet');
    }

    logger.warning('Unknown API config type: ${apiConfig.runtimeType}');
    throw UnsupportedError('Unknown API config type');
  }

  List<ToolDefinition> _getAvailableToolsForAgent(
    TextAgentInfo agent,
    Set<String> activeExtensions,
  ) {
    if (_toolRunner == null) {
      logger.fine('No ToolRunner available, returning empty tools list');
      return const [];
    }

    // Get tools filtered by active file extensions
    final extensionFilteredTools =
        _toolRunner!.computeAvailableTools(activeExtensions);

    // If agent's enabledTools is empty, all extension-filtered tools are enabled
    if (agent.enabledTools.isEmpty) {
      logger.fine(
          'Agent ${agent.id}: ${extensionFilteredTools.length} tools available (no agent-level filtering)');
      return extensionFilteredTools;
    }

    // Further filter by agent's enabled tools (key-absent = true convention)
    final filtered = extensionFilteredTools.where((tool) {
      return agent.enabledTools[tool.toolKey] ?? true;
    }).toList();
    
    logger.fine(
        'Agent ${agent.id}: ${filtered.length}/${extensionFilteredTools.length} tools available after agent filtering');
    return filtered;
  }

  bool _isContextLengthError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('context_length_exceeded') ||
        errorStr.contains('context length') ||
        errorStr.contains('maximum context') ||
        errorStr.contains('token limit') ||
        errorStr.contains('tokens exceeded');
  }

  void _registerAgents(Iterable<TextAgentInfo> agents) {
    logger.fine('Registering ${agents.length} text agents');
    for (final agent in agents) {
      final existing = _agentsById[agent.id];
      if (existing != null) {
        logger.warning('Duplicate text agent id: ${agent.id}');
        throw ArgumentError.value(
          agent.id,
          'agents',
          'Duplicate text agent id: ${agent.id}',
        );
      }
      _agentsById[agent.id] = agent;
      logger.fine('Registered agent: ${agent.id} (${agent.name})');
    }
  }

  @override
  Future<void> start() async {
    await super.start();
    logger.info('Starting TextAgentService with ${_agentsById.length} agents');
  }

  /// Execute a query with multi-turn tool calling support.
  ///
  /// Returns the final text response from the agent after all tool calls complete.
  /// Recomputes available tools on each turn to reflect active file changes.
  Future<String> _executeQueryLoop({
    required TextAgentInfo agent,
    required TextAgentThread thread,
    required TextAgentTransport transport,
  }) async {
    const maxTurns = 10;
    int turnCount = 0;

    logger.fine('Starting query execution loop for agent: ${agent.id}');

    while (turnCount < maxTurns) {
      turnCount++;
      logger.fine('Executing turn $turnCount/$maxTurns');

      // Recompute available tools based on current active file extensions
      final activeExtensions = _getCurrentActiveExtensions();
      logger.fine('Active file extensions: ${activeExtensions.join(", ")}');
      final availableTools = _getAvailableToolsForAgent(agent, activeExtensions);

      // Send request via transport (transport handles tool format conversion)
      logger.fine('Sending API request with ${availableTools.length} tools');
      final responseJson = await transport.sendRequest(
        thread: thread,
        systemPrompt: agent.prompt,
        availableTools: availableTools,
      );

      // Parse response
      final choices = responseJson['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        logger.severe('No choices in API response');
        throw Exception('No choices in API response');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message == null) {
        logger.severe('No message in API response');
        throw Exception('No message in API response');
      }

      // Check for tool calls
      final toolCalls = message['tool_calls'] as List?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        logger.info('Agent requested ${toolCalls.length} tool call(s)');
        
        // AI requested tool execution
        // Convert tool calls to domain model
        final domainToolCalls = <TextAgentToolCall>[];

        for (final toolCallData in toolCalls) {
          final toolCallId = toolCallData['id'] as String;
          final function = toolCallData['function'] as Map<String, dynamic>;
          final toolName = function['name'] as String;
          final argumentsStr = function['arguments'] as String;

          logger.info('Tool call: $toolName (id: $toolCallId)');
          logger.fine('Tool arguments: $argumentsStr');

          domainToolCalls.add(TextAgentToolCall(
            id: toolCallId,
            name: toolName,
            arguments: argumentsStr,
          ));
        }

        // Add assistant message with tool calls to thread
        final assistantItem = TextAgentThreadItem(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          type: TextAgentThreadItemType.message,
          role: TextAgentThreadItemRole.assistant,
          status: TextAgentThreadItemStatus.completed,
          toolCalls: domainToolCalls,
        );
        thread.addItem(assistantItem);

        // Execute each tool and add results
        for (final toolCall in domainToolCalls) {
          String toolResult;
          try {
            if (_toolRunner == null) {
              throw StateError('ToolRunner not available');
            }
            logger.fine('Executing tool: ${toolCall.name}');
            toolResult =
                await _toolRunner!.execute(toolCall.name, toolCall.arguments);
            logger.fine('Tool execution succeeded: ${toolCall.name}');
          } catch (e, stackTrace) {
            logger.severe('Tool execution failed: ${toolCall.name}', e, stackTrace);
            toolResult = jsonEncode({
              'success': false,
              'error': 'Tool execution failed: $e',
            });
          }

          // Add toolResult item to thread
          final toolResultItem = TextAgentThreadItem(
            id: '${toolCall.id}_result',
            type: TextAgentThreadItemType.toolResult,
            status: TextAgentThreadItemStatus.completed,
            toolCallId: toolCall.id,
            toolName: toolCall.name,
            toolOutput: toolResult,
          );
          thread.addItem(toolResultItem);
        }

        // Continue loop for next turn
        continue;
      }

      // No tool calls - get final response
      final content = message['content'] as String?;
      if (content == null) {
        logger.severe('No content in final response');
        throw Exception('No content in final response');
      }

      logger.info('Query loop completed in $turnCount turns');
      
      // Add final assistant message item to thread
      final textPart = TextAgentThreadTextPart(text: content, isDone: true);
      final assistantItem = TextAgentThreadItem(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        type: TextAgentThreadItemType.message,
        role: TextAgentThreadItemRole.assistant,
        status: TextAgentThreadItemStatus.completed,
        content: [textPart],
      );
      thread.addItem(assistantItem);

      return content;
    }

    // Max turns reached
    logger.warning('Query loop reached max turns ($maxTurns) without completion');
    throw Exception('Max turns ($maxTurns) reached without completion');
  }

  Set<String> _getCurrentActiveExtensions() {
    if (_notepadService == null) {
      return const {};
    }

    final activeFiles = _notepadService!.listActive();
    return activeFiles
        .map((file) => file.extension.toLowerCase())
        .where((ext) => ext.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> dispose() async {
    logger.info('Disposing TextAgentService (${_agentsById.length} agents, ${_threadsByAgent.length} threads)');
    await super.dispose();
    _agentsById.clear();
    _threadsByAgent.clear();
    _notepadService = null;
    _toolRunner = null;
    logger.info('TextAgentService disposed successfully');
  }
}
