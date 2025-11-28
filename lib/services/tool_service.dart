import 'storage_service.dart';
import 'notepad_service.dart';
import 'tools/tool_manager.dart';
import 'tools/builtin_tool_factory.dart';

// Re-export for backward compatibility
export 'tools/base_tool.dart' show BaseTool, ToolExecutionResult, ToolManagerRef;
export 'tools/tool_manager.dart' show ToolManager;

/// Factory for creating session-scoped ToolManager instances
/// 
/// The ToolService itself is application-scoped but creates
/// session-scoped ToolManager instances for each call.
class ToolService {
  final StorageService _storage;
  final NotepadService _notepadService;
  late final BuiltinToolFactory _builtinFactory;
  
  ToolService({
    required StorageService storage,
    required NotepadService notepadService,
  }) : _storage = storage, _notepadService = notepadService {
    _builtinFactory = BuiltinToolFactory(
      storage: _storage,
      notepadService: _notepadService,
    );
  }
  
  /// Create a new session-scoped ToolManager
  /// Called when starting a call
  ToolManager createToolManager({void Function()? onToolsChanged}) {
    final manager = ToolManager(onToolsChanged: onToolsChanged);
    manager.registerTools(_builtinFactory.createBuiltinTools());
    return manager;
  }
  
  /// Get tool definitions without creating a manager
  /// (for backwards compatibility with existing code)
  List<Map<String, dynamic>> get toolDefinitions {
    final tools = _builtinFactory.createBuiltinTools();
    return tools.map((t) => t.toJson()).toList();
  }
}
