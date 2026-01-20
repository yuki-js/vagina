import 'package:vagina/services/tools_runtime/apis/notepad_api.dart';
import 'package:vagina/services/tools_runtime/apis/memory_api.dart';
import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';
import 'package:vagina/services/tools_runtime/apis/tool_storage_api.dart';

/// Per-call dependency container for tools.
///
/// This holds abstract API interfaces that tools use to interact with
/// the host application. This abstraction allows tools to run in isolates
/// while maintaining a clean separation of concerns.
///
/// **Implementations:**
/// - For isolate execution: Use [NotepadApiClient], [MemoryApiClient],
///   [CallApiClient], [TextAgentApiClient], and [ToolStorageApiClient]
///   which communicate with the host via message passing.
/// - For testing/host-side: Create direct wrapper implementations that
///   delegate to actual services.
class ToolContext {
  /// Unique identifier of the tool (for storage isolation and tracking)
  final String toolKey;

  /// Abstract API for notepad operations.
  ///
  /// Tools use this to access and mutate the current notepad state.
  /// This is Flutter-free and can be implemented via message passing for isolates.
  final NotepadApi notepadApi;

  /// Abstract API for memory/recall operations.
  ///
  /// Tools use this to save and retrieve persistent memories.
  /// This is Flutter-free and can be implemented via message passing for isolates.
  final MemoryApi memoryApi;

  /// Abstract API for call control operations.
  ///
  /// Tools use this to control call behavior (e.g., ending calls).
  /// This is Flutter-free and can be implemented via message passing for isolates.
  final CallApi callApi;

  /// Abstract API for text agent query operations.
  ///
  /// Tools use this to query text agents and retrieve results.
  /// This is Flutter-free and can be implemented via message passing for isolates.
  final TextAgentApi textAgentApi;

  /// Abstract API for tool-isolated storage operations.
  ///
  /// Tools use this to persist and retrieve their own isolated data.
  /// Each tool has its own namespace, preventing cross-tool data access.
  /// This is Flutter-free and can be implemented via message passing for isolates.
  final ToolStorageApi toolStorageApi;

  ToolContext({
    required this.toolKey,
    required this.notepadApi,
    required this.memoryApi,
    required this.callApi,
    required this.textAgentApi,
    required this.toolStorageApi,
  });
}
