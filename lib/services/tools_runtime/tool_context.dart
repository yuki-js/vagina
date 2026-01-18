import 'package:vagina/services/tools_runtime/apis/notepad_api.dart';
import 'package:vagina/services/tools_runtime/apis/memory_api.dart';

/// Per-call dependency container for tools.
///
/// This holds abstract API interfaces that tools use to interact with
/// the host application. This abstraction allows tools to run in isolates
/// while maintaining a clean separation of concerns.
///
/// **Implementations:**
/// - For isolate execution: Use [NotepadApiClient] and [MemoryApiClient]
///   which communicate with the host via message passing.
/// - For testing/host-side: Create direct wrapper implementations that
///   delegate to actual services.
class ToolContext {
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

  ToolContext({
    required this.notepadApi,
    required this.memoryApi,
  });
}
