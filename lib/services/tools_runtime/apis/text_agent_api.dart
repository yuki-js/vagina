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
  final Future<dynamic> Function(String method, Map<String, dynamic> args)
      hostCall;

  TextAgentApiClient({required this.hostCall});

  @override
  Future<Map<String, dynamic>> sendQuery(
    String agentId,
    String prompt,
    String expectLatency,
  ) async {
    final payload = {
      'agentId': agentId,
      'prompt': prompt,
      'expectLatency': expectLatency,
    };

    final data = await hostCall('sendQuery', payload);

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw StateError(
      'Invalid textAgent.sendQuery response type: ${data.runtimeType}',
    );
  }

  @override
  Future<Map<String, dynamic>> getResult(String token) async {
    final data = await hostCall('getResult', {'token': token});

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw StateError(
      'Invalid textAgent.getResult response type: ${data.runtimeType}',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listAgents() async {
    final data = await hostCall('listAgents', <String, dynamic>{});

    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((agent) => Map<String, dynamic>.from(agent as Map)),
      );
    }

    throw StateError(
      'Invalid textAgent.listAgents response type: ${data.runtimeType}',
    );
  }
}
