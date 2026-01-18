import 'package:vagina/services/tools/base_tool.dart';

import 'legacy_base_tool_adapter.dart';
import 'tool_factory.dart';
import 'tool.dart';

/// Runtime [ToolFactory] that creates a fresh legacy [BaseTool] instance and
/// wraps it with [LegacyBaseToolAdapter].
///
/// This enables the per-call runtime layer to execute existing legacy tools
/// without reusing tool instances across calls.
class LegacyToolFactory implements ToolFactory {
  final BaseTool Function() _createLegacy;
  final ToolManagerRef? _managerRef;

  LegacyToolFactory({
    required BaseTool Function() createLegacy,
    ToolManagerRef? managerRef,
  })  : _createLegacy = createLegacy,
        _managerRef = managerRef;

  @override
  Tool createTool() {
    final legacy = _createLegacy();
    final managerRef = _managerRef;
    if (managerRef != null) {
      legacy.setManagerRef(managerRef);
    }
    return LegacyBaseToolAdapter(legacy);
  }
}
