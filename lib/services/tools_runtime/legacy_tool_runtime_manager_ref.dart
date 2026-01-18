import 'dart:convert';

import 'package:vagina/services/tools/base_tool.dart';

import 'tool_runtime.dart';

/// Minimal [ToolManagerRef] implementation backed by a [ToolRuntime].
///
/// This exists to preserve the legacy capability where a running tool can
/// request mid-call tool updates.
///
/// The implementation does not attempt to mutate the runtime in-place.
/// Instead it records pending changes and notifies the owner via
/// [onToolsChanged]. The owner is expected to rebuild and push new tool
/// definitions to the Realtime session.
class LegacyToolRuntimeManagerRef implements ToolManagerRef {
  final ToolRuntime _runtime;
  final void Function()? _onToolsChanged;

  final Set<String> _registered = <String>{};
  final Set<String> _unregistered = <String>{};

  LegacyToolRuntimeManagerRef({
    required ToolRuntime runtime,
    void Function()? onToolsChanged,
  })  : _runtime = runtime,
        _onToolsChanged = onToolsChanged;

  /// Snapshot of tool keys requested to be registered by tools mid-call.
  Set<String> get requestedRegistrations => Set<String>.from(_registered);

  /// Snapshot of tool keys requested to be unregistered by tools mid-call.
  Set<String> get requestedUnregistrations => Set<String>.from(_unregistered);

  @override
  void registerTool(BaseTool tool) {
    _registered.add(tool.name);
    _unregistered.remove(tool.name);
    _onToolsChanged?.call();
  }

  @override
  void unregisterTool(String name) {
    _unregistered.add(name);
    _registered.remove(name);
    _onToolsChanged?.call();
  }

  @override
  bool hasTool(String name) => _runtime.getTool(name) != null;

  @override
  List<String> get registeredToolNames =>
      _runtime.toolDefinitionsForRealtime
          .map((t) => t['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList(growable: false);

  /// Legacy-style error payload helper.
  static String errorPayload(String message) => jsonEncode({'error': message});
}
