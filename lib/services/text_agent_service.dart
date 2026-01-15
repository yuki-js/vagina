import 'dart:async';
import '../models/text_agent.dart';
import '../services/log_service.dart';

/// Service for managing text agent queries and responses
/// 
/// Provides advanced reasoning capabilities through text-based agents
/// with support for synchronous and asynchronous queries based on expected latency.
class TextAgentService {
  static const _tag = 'TextAgent';
  
  final LogService _logService;
  final Map<String, TextAgent> _agents = {};
  final Map<String, Completer<TextAgentResponse>> _pendingRequests = {};
  final Map<String, TextAgentResponse> _cachedResponses = {};
  
  TextAgentService({LogService? logService})
      : _logService = logService ?? LogService() {
    _initializeDefaultAgents();
  }

  /// Initialize default text agents
  void _initializeDefaultAgents() {
    // Add default agents
    final defaultAgents = [
      const TextAgent(
        id: 'gpt-4o',
        name: 'GPT-4o',
        description: 'OpenAI GPT-4o - Fast and capable general-purpose model',
        modelIdentifier: 'gpt-4o',
        capabilities: ['general', 'reasoning', 'coding'],
        isAvailable: true,
      ),
      const TextAgent(
        id: 'gpt-4o-mini',
        name: 'GPT-4o Mini',
        description: 'OpenAI GPT-4o Mini - Fast and efficient for simple tasks',
        modelIdentifier: 'gpt-4o-mini',
        capabilities: ['general', 'fast'],
        isAvailable: true,
      ),
      const TextAgent(
        id: 'o1',
        name: 'o1',
        description: 'OpenAI o1 - Advanced reasoning model with deep thinking',
        modelIdentifier: 'o1',
        capabilities: ['reasoning', 'complex-problems', 'deep-thinking'],
        isAvailable: true,
      ),
      const TextAgent(
        id: 'o1-mini',
        name: 'o1 Mini',
        description: 'OpenAI o1 Mini - Efficient reasoning for focused tasks',
        modelIdentifier: 'o1-mini',
        capabilities: ['reasoning', 'focused-tasks'],
        isAvailable: true,
      ),
    ];

    for (final agent in defaultAgents) {
      _agents[agent.id] = agent;
    }
    
    _logService.info(_tag, 'Initialized ${_agents.length} default text agents');
  }

  /// Get list of available text agents
  List<TextAgent> listAvailableAgents() {
    return _agents.values.where((agent) => agent.isAvailable).toList();
  }

  /// Get a specific text agent by ID
  TextAgent? getAgent(String agentId) {
    return _agents[agentId];
  }

  /// Register a new text agent
  void registerAgent(TextAgent agent) {
    _agents[agent.id] = agent;
    _logService.info(_tag, 'Registered agent: ${agent.id} (${agent.name})');
  }

  /// Unregister a text agent
  void unregisterAgent(String agentId) {
    if (_agents.remove(agentId) != null) {
      _logService.info(_tag, 'Unregistered agent: $agentId');
    }
  }

  /// Query a text agent with specified latency expectation
  /// 
  /// For instant queries, returns response directly
  /// For long/ultra_long queries, returns request ID for later retrieval
  Future<dynamic> queryTextAgent({
    required String agentId,
    required String prompt,
    required AgentLatency expectLatency,
  }) async {
    final agent = _agents[agentId];
    if (agent == null) {
      throw ArgumentError('Text agent not found: $agentId');
    }

    if (!agent.isAvailable) {
      throw StateError('Text agent not available: $agentId');
    }

    _logService.debug(_tag, 
        'Query to agent $agentId with latency ${expectLatency.value}: ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');

    switch (expectLatency) {
      case AgentLatency.instant:
        return await _executeInstantQuery(agent, prompt);
      
      case AgentLatency.long:
      case AgentLatency.ultraLong:
        return await _createAsyncQuery(agent, prompt, expectLatency);
    }
  }

  /// Execute instant query and return response directly
  Future<TextAgentResponse> _executeInstantQuery(
    TextAgent agent,
    String prompt,
  ) async {
    try {
      // TODO: Implement actual API call to text agent
      // For now, return a mock response
      await Future.delayed(const Duration(milliseconds: 500));
      
      final response = TextAgentResponse(
        content: 'Mock response from ${agent.name} to: $prompt',
        isComplete: true,
        timestamp: DateTime.now(),
      );
      
      _logService.info(_tag, 'Instant query completed for agent ${agent.id}');
      return response;
    } catch (e) {
      _logService.error(_tag, 'Failed to execute instant query: $e');
      rethrow;
    }
  }

  /// Create async query and return request ID
  Future<String> _createAsyncQuery(
    TextAgent agent,
    String prompt,
    AgentLatency expectLatency,
  ) async {
    final requestId = '${agent.id}_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<TextAgentResponse>();
    _pendingRequests[requestId] = completer;

    _logService.info(_tag, 
        'Created async query $requestId for agent ${agent.id} with latency ${expectLatency.value}');

    // Start async processing
    _processAsyncQuery(agent, prompt, requestId, expectLatency);

    return requestId;
  }

  /// Process async query in background
  Future<void> _processAsyncQuery(
    TextAgent agent,
    String prompt,
    String requestId,
    AgentLatency expectLatency,
  ) async {
    try {
      // Simulate processing delay based on latency
      final delay = expectLatency == AgentLatency.long
          ? const Duration(seconds: 5)
          : const Duration(seconds: 15);
      
      await Future.delayed(delay);
      
      // TODO: Implement actual API call to text agent
      final response = TextAgentResponse(
        content: 'Async response from ${agent.name} to: $prompt',
        requestId: requestId,
        isComplete: true,
        timestamp: DateTime.now(),
      );

      // Cache the response
      _cachedResponses[requestId] = response;
      
      // Complete the pending request
      final completer = _pendingRequests[requestId];
      if (completer != null && !completer.isCompleted) {
        completer.complete(response);
      }
      
      _logService.info(_tag, 'Async query completed: $requestId');
    } catch (e) {
      _logService.error(_tag, 'Failed to process async query: $e');
      
      final completer = _pendingRequests[requestId];
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e);
      }
    }
  }

  /// Get response for async query by request ID
  /// 
  /// Returns null if response is not yet ready
  /// Throws if request ID is invalid
  Future<TextAgentResponse?> getTextAgentResponse(String requestId) async {
    // Check cache first
    if (_cachedResponses.containsKey(requestId)) {
      final response = _cachedResponses[requestId]!;
      _logService.debug(_tag, 'Retrieved cached response for $requestId');
      return response;
    }

    // Check if request is pending
    final completer = _pendingRequests[requestId];
    if (completer == null) {
      throw ArgumentError('Invalid request ID: $requestId');
    }

    // Check if it's completed without blocking
    if (completer.isCompleted) {
      final response = await completer.future;
      _cachedResponses[requestId] = response;
      return response;
    }

    // Not ready yet
    _logService.debug(_tag, 'Response not yet ready for $requestId');
    return null;
  }

  /// Check if async query is complete
  bool isQueryComplete(String requestId) {
    if (_cachedResponses.containsKey(requestId)) {
      return true;
    }
    
    final completer = _pendingRequests[requestId];
    return completer?.isCompleted ?? false;
  }

  /// Cancel pending async query
  void cancelQuery(String requestId) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        StateError('Query cancelled: $requestId'),
      );
      _logService.info(_tag, 'Cancelled query: $requestId');
    }
    _cachedResponses.remove(requestId);
  }

  /// Clear cached responses older than specified duration
  void clearOldResponses({Duration maxAge = const Duration(hours: 1)}) {
    final now = DateTime.now();
    final toRemove = <String>[];
    
    _cachedResponses.forEach((requestId, response) {
      if (now.difference(response.timestamp) > maxAge) {
        toRemove.add(requestId);
      }
    });

    for (final requestId in toRemove) {
      _cachedResponses.remove(requestId);
      _pendingRequests.remove(requestId);
    }

    if (toRemove.isNotEmpty) {
      _logService.info(_tag, 'Cleared ${toRemove.length} old responses');
    }
  }

  /// Dispose service and clean up resources
  void dispose() {
    // Cancel all pending requests
    for (final requestId in _pendingRequests.keys.toList()) {
      cancelQuery(requestId);
    }
    
    _cachedResponses.clear();
    _logService.info(_tag, 'Text agent service disposed');
  }
}
