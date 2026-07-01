/// Abstract API for text agent query operations.
///
/// This API allows tools to query text agents through the current call/session
/// boundary. Implementations must not expose private text-model configuration
/// details through [listAgents].
abstract class TextAgentApi {
  /// Send a query to a text agent and return the response text.
  Future<String> sendQuery(
    String agentId,
    String prompt, {
    void Function() Function(void Function())? onCancel,
  });

  /// List all available text agents.
  ///
  /// Returns safe agent metadata maps suitable for tool/runtime exposure.
  /// Tool fields use sparse override semantics: empty [enabled_tools] means
  /// default-enabled catalog tools except policy-denied tools, not "no tools".
  Future<List<Map<String, dynamic>>> listAgents();
}
