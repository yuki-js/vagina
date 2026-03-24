import 'package:vagina/feat/callv2/models/text_agent_info.dart';

/// Session-scoped text-agent domain service for a single CallV2 session.
///
/// This service is intentionally introduced as a service boundary rather than
/// an API adapter. It currently owns only session lifecycle wiring and the
/// immutable in-call agent registry. Query execution and tool-facing API
/// adaptation remain outside this service for now.
class TextAgentService {
  /// Start the service.
  ///
  /// Reserved for future session-scoped initialization such as thread stores,
  /// state machine setup, transport preparation, or telemetry hooks.
  Future<void> start() async {}

  /// Dispose the service and release session-scoped resources.
  Future<void> dispose() async {}
}
