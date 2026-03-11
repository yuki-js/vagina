import 'package:vagina/services/tools_runtime/apis/call_api.dart';
import 'package:vagina/services/tools_runtime/apis/filesystem_api.dart';
import 'package:vagina/services/tools_runtime/apis/text_agent_api.dart';

/// Per-call dependency container for tools.
///
/// This holds abstract API interfaces that tools use to interact with
/// the host application. This abstraction allows tools to run in isolates
/// while maintaining a clean separation of concerns.
///
/// **Implementations:**
/// - For isolate execution: Use [FilesystemApiClient], [CallApiClient], and
///   [TextAgentApiClient]
///   which communicate with the host via message passing.
/// - For testing/host-side: Create direct wrapper implementations that
///   delegate to actual services.
class ToolContext {
  /// Unique identifier of the tool (for storage isolation and tracking)
  final String toolKey;

  /// Abstract API for virtual filesystem operations.
  ///
  /// Tools use this for persistent file operations and runtime open-file state.
  /// This is Flutter-free and can be implemented via message passing for isolates.
  final FilesystemApi filesystemApi;

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

  ToolContext({
    required this.toolKey,
    required this.filesystemApi,
    required this.callApi,
    required this.textAgentApi,
  });

  @Deprecated(
    'notepadApi was removed in Stream B. Migrate tools to filesystemApi.',
  )
  dynamic get notepadApi {
    throw UnsupportedError(
      'notepadApi was removed. Migrate this tool to filesystemApi.',
    );
  }

  @Deprecated(
    'toolStorageApi was removed in Stream B. Migrate tools to filesystemApi.',
  )
  dynamic get toolStorageApi {
    throw UnsupportedError(
      'toolStorageApi was removed. Migrate this tool to filesystemApi.',
    );
  }
}
