import 'dart:convert';

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

/// Client implementation of TextAgentApi that uses hostCall for isolate communication
class TextAgentApiClient implements TextAgentApi {
  static const _tag = 'TextAgentApiClient';
  final Future<Map<String, dynamic>> Function(
      String method, Map<String, dynamic> args) hostCall;

  TextAgentApiClient({required this.hostCall});

  @override
  Future<Map<String, dynamic>> sendQuery(
    String agentId,
    String prompt,
    String expectLatency,
  ) async {
    try {
      final payload = {
        'agentId': agentId,
        'prompt': prompt,
        'expectLatency': expectLatency,
      };
      final result = await hostCall('sendQuery', payload);

      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && result['success'] == true) {
        return data;
      }

      // Handle error
      final error = data?['error'] ?? result['error'] ?? 'Failed to send query';
      print(
          '[TOOL:GUEST] $_tag - Failed to call textAgent.sendQuery\nError: $error\nRequest Payload: ${jsonEncode(payload)}');
      throw error;
    } catch (e) {
      print(
          '[TOOL:GUEST] $_tag - Exception in sendQuery: $e\nRequest Payload: ${jsonEncode({
            'agentId': agentId,
            'prompt': prompt,
            'expectLatency': expectLatency
          })}');
      throw Exception('Error sending query: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getResult(String token) async {
    try {
      final payload = {'token': token};
      final result = await hostCall('getResult', payload);

      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && result['success'] == true) {
        return data;
      }

      // Handle error
      final error = data?['error'] ?? result['error'] ?? 'Failed to get result';
      print(
          '[TOOL:GUEST] $_tag - Failed to call textAgent.getResult\nError: $error\nRequest Payload: ${jsonEncode(payload)}');
      throw error;
    } catch (e) {
      print(
          '[TOOL:GUEST] $_tag - Exception in getResult: $e\nRequest Payload: ${jsonEncode({
            'token': token
          })}');
      throw Exception('Error getting result: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    try {
      final payload = <String, dynamic>{};
      final result = await hostCall('listAgents', payload);

      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && result['success'] == true && data['agents'] is List) {
        return List<Map<String, dynamic>>.from((data['agents'] as List)
            .map((agent) => Map<String, dynamic>.from(agent as Map)));
      }

      // Handle error
      final error =
          data?['error'] ?? result['error'] ?? 'Failed to list agents';
      print(
          '[TOOL:GUEST] $_tag - Failed to call textAgent.listAgents\nError: $error\nRequest Payload: ${jsonEncode(payload)}');
      throw error;
    } catch (e) {
      print(
          '[TOOL:GUEST] $_tag - Exception in listAgents: $e\nRequest Payload: ${jsonEncode({})}');
      throw Exception('Error listing agents: $e');
    }
  }
}
