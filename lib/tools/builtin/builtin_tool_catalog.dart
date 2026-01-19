import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/services/tools_runtime/tool_factory.dart' as runtime;

// Import all builtin tools
import 'calculator_tool.dart';
import 'document_overwrite_tool.dart';
import 'document_patch_tool.dart';
import 'document_read_tool.dart';
import 'get_current_time_tool.dart';
import 'memory_delete_tool.dart';
import 'memory_recall_tool.dart';
import 'memory_save_tool.dart';
import 'notepad_close_tab_tool.dart';
import 'notepad_get_content_tool.dart';
import 'notepad_get_metadata_tool.dart';
import 'notepad_list_tabs_tool.dart';
import 'call/end_call_tool.dart';
import 'text_agent/get_text_agent_response_tool.dart';
import 'text_agent/list_available_agents_tool.dart';
import 'text_agent/query_text_agent_tool.dart';

/// Exception thrown when an unknown tool is requested
class UnknownToolException implements Exception {
  final String toolKey;

  UnknownToolException(this.toolKey);

  @override
  String toString() => 'Unknown tool: $toolKey';
}

/// Factory function type for creating builtin tool instances.
///
/// Named to avoid colliding with runtime's `ToolFactory` interface.
typedef BuiltinToolFactory = Tool Function();

/// Catalog of all builtin tools
class BuiltinToolCatalog {
  /// Map of tool key to factory function
  static final Map<String, BuiltinToolFactory> _factories = {
    CalculatorTool.toolKeyName: () => CalculatorTool(),
    DocumentOverwriteTool.toolKeyName: () => DocumentOverwriteTool(),
    DocumentPatchTool.toolKeyName: () => DocumentPatchTool(),
    DocumentReadTool.toolKeyName: () => DocumentReadTool(),
    GetCurrentTimeTool.toolKeyName: () => GetCurrentTimeTool(),
    MemoryDeleteTool.toolKeyName: () => MemoryDeleteTool(),
    MemoryRecallTool.toolKeyName: () => MemoryRecallTool(),
    MemorySaveTool.toolKeyName: () => MemorySaveTool(),
    NotepadCloseTabTool.toolKeyName: () => NotepadCloseTabTool(),
    NotepadGetContentTool.toolKeyName: () => NotepadGetContentTool(),
    NotepadGetMetadataTool.toolKeyName: () => NotepadGetMetadataTool(),
    NotepadListTabsTool.toolKeyName: () => NotepadListTabsTool(),
    EndCallTool.toolKeyName: () => EndCallTool(),
    GetTextAgentResponseTool.toolKeyName: () => GetTextAgentResponseTool(),
    ListAvailableAgentsTool.toolKeyName: () => ListAvailableAgentsTool(),
    QueryTextAgentTool.toolKeyName: () => QueryTextAgentTool(),
  };

  /// List all builtin tool definitions
  static List<ToolDefinition> listDefinitions() {
    return _factories.values
        .map((factory) => factory().definition)
        .cast<ToolDefinition>()
        .toList();
  }

  /// Exposes builtin tools as runtime [ToolFactory]s.
  ///
  /// This is used by UI code that reads tool definitions via the runtime
  /// registry ([`ToolRegistry`](lib/services/tools_runtime/tool_registry.dart:13)).
  static Map<String, runtime.ToolFactory> listRuntimeFactories() {
    return _factories.map(
      (toolKey, factory) => MapEntry(
        toolKey,
        runtime.SimpleToolFactory(create: factory),
      ),
    );
  }

  /// Create a tool instance by toolKey
  static Tool createTool(String toolKey, ToolContext context) {
    final factory = _factories[toolKey];
    if (factory == null) {
      throw UnknownToolException(toolKey);
    }
    return factory();
  }

  /// Get all registered tool keys
  static Set<String> getAvailableToolKeys() {
    return _factories.keys.toSet();
  }

  /// Check if a tool is registered
  static bool isToolAvailable(String toolKey) {
    return _factories.containsKey(toolKey);
  }
}
