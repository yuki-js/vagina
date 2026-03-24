import 'package:vagina/feat/callv2/models/text_agent_thread.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// Abstract transport for sending text-agent queries to provider-specific APIs.
///
/// Implementations handle the conversion from domain-level [TextAgentThread]
/// and [ToolDefinition] to provider-specific request formats and back to response data.
abstract class TextAgentTransport {
  /// Send a query request with the given thread and system prompt.
  ///
  /// Returns the raw response data from the provider API, which the caller
  /// should parse to extract messages, tool calls, etc.
  ///
  /// Throws on network errors, API errors, or timeout.
  Future<Map<String, dynamic>> sendRequest({
    required TextAgentThread thread,
    required String systemPrompt,
    required List<ToolDefinition> availableTools,
    required Duration timeout,
  });

  /// Dispose transport resources (e.g., HTTP client).
  Future<void> dispose();
}
