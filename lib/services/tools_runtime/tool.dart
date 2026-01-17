import 'tool_context.dart';
import 'tool_definition.dart';

/// Parsed arguments passed to a tool.
typedef ToolArgs = Map<String, dynamic>;

/// Tool runtime interface.
///
/// Implementations should be Flutter-free.
abstract class Tool {
  ToolDefinition get definition;

  /// Performs one-time initialization for this instance.
  ///
  /// This must be safe to call multiple times (at-most-once per instance).
  /// Implementations may use [AsyncOnce] to enforce the latch semantics.
  Future<void> init();

  /// Executes the tool.
  ///
  /// [args] must already be parsed from JSON.
  /// Returns a JSON payload string for compatibility with the existing
  /// tool-call plumbing.
  Future<String> execute(ToolArgs args, ToolContext context);
}

/// Helper for implementing at-most-once async initialization.
class AsyncOnce<T> {
  Future<T>? _future;

  Future<T> run(Future<T> Function() action) {
    return _future ??= action();
  }
}
