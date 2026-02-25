import 'tool_context.dart';
import 'tool_definition.dart';

/// Tool runtime interface.
///
/// Implementations should be Flutter-free.
///
/// Note:
/// - Tools execute inside the sandbox worker.
/// - The host process only needs tool *definitions* for UI + model registration.
abstract class Tool {
  ToolDefinition get definition;

  late final ToolContext context;

  /// Called by the sandbox worker to provide the per-tool context.
  Future<void> init(ToolContext c) async {
    context = c;
  }

  /// Execute the tool and return a JSON string.
  Future<String> execute(Map<String, dynamic> args);

  /// Serialize tool metadata for transport over the sandbox protocol.
  Map<String, dynamic> toWireJson() {
    return {
      'toolKey': definition.toolKey,
      'definition': definition.toJson(),
    };
  }

  /// Deserialize a host-side tool reference from sandbox protocol payload.
  ///
  /// The returned tool is NOT executable on the host. Use
  /// `ToolSandboxManager.execute()` to execute tools in the sandbox.
  static Tool fromWireJson(Map<String, dynamic> json) {
    final definitionJson = json['definition'];
    if (definitionJson is! Map) {
      throw StateError('Invalid tool wire JSON: missing "definition"');
    }

    final def = ToolDefinition.fromJson(
      Map<String, dynamic>.from(definitionJson),
    );
    return ToolReference(def);
  }
}

/// Host-side tool reference.
///
/// Carries only tool metadata and cannot be executed locally.
class ToolReference extends Tool {
  final ToolDefinition _definition;

  ToolReference(this._definition);

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<void> init(ToolContext c) async {
    throw UnsupportedError('ToolReference does not support init()');
  }

  @override
  Future<String> execute(Map<String, dynamic> args) {
    throw UnsupportedError(
      'ToolReference cannot execute. Use ToolSandboxManager.execute().',
    );
  }
}
