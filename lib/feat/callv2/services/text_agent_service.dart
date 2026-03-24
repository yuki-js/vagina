import 'dart:collection';

import 'package:vagina/feat/callv2/models/text_agent_info.dart';

/// Session-scoped text-agent domain service for a single CallV2 session.
///
/// This service is intentionally introduced as a service boundary rather than
/// an API adapter. At this stage it owns only session lifecycle wiring and the
/// immutable in-call agent registry. Query execution and tool-facing API
/// adaptation remain outside this service for now.
class TextAgentService {
  final Map<String, TextAgentInfo> _agentsById = <String, TextAgentInfo>{};

  bool _started = false;
  bool _disposed = false;

  TextAgentService({
    Iterable<TextAgentInfo> agents = const <TextAgentInfo>[],
  }) {
    _registerAgents(agents);
  }

  /// Read-only view of the text agents available during this call.
  List<TextAgentInfo> get agents =>
      UnmodifiableListView<TextAgentInfo>(_agentsById.values);

  /// Whether [start] has been called successfully.
  bool get isStarted => _started;

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

  /// Start the service.
  Future<void> start() async {
    if (_disposed) {
      throw StateError('TextAgentService has already been disposed.');
    }
    if (_started) {
      return;
    }
    _started = true;
  }

  /// Dispose the service and release session-scoped resources.
  Future<void> dispose() async {
    _agentsById.clear();
    _started = false;
    _disposed = true;
  }
}
