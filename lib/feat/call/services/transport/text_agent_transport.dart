import 'package:vagina/feat/call/models/text_agent_thread.dart';
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
  /// Throws on network errors or API errors.
  Future<Map<String, dynamic>> sendRequest({
    required TextAgentThread thread,
    required String systemPrompt,
    required List<ToolDefinition> availableTools,
  });

  /// Dispose transport resources (e.g., HTTP client).
  Future<void> dispose();
}
