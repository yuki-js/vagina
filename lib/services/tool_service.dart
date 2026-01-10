import 'notepad_service.dart';
import 'tools/tool_manager.dart';
import 'tools/builtin_tool_factory.dart';
import '../repositories/repository_factory.dart';

export 'tools/base_tool.dart' show BaseTool, ToolExecutionResult, ToolManagerRef;
export 'tools/tool_manager.dart' show ToolManager;

/// Factory for creating session-scoped ToolManager instances
/// 
/// The ToolService itself is application-scoped but creates
/// session-scoped ToolManager instances for each call.
class ToolService {
  final NotepadService _notepadService;
  late final BuiltinToolFactory _builtinFactory;
  
  ToolService({
    required NotepadService notepadService,
  }) : _notepadService = notepadService {
    _builtinFactory = BuiltinToolFactory(
      memoryRepository: RepositoryFactory.memory,
      notepadService: _notepadService,
    );
  }
  
  /// Create a new session-scoped ToolManager
  /// Called when starting a call - only registers enabled tools
  Future<ToolManager> createToolManager({void Function()? onToolsChanged}) async {
    final manager = ToolManager(onToolsChanged: onToolsChanged);
    final allTools = _builtinFactory.createBuiltinTools();
    final enabledTools = await RepositoryFactory.config.getEnabledTools();
    
    // Filter tools based on user preferences
    final toolsToRegister = enabledTools.isEmpty
        ? allTools // If no preferences, enable all
        : allTools.where((tool) => enabledTools.contains(tool.name)).toList();
    
    manager.registerTools(toolsToRegister);
    return manager;
  }
  
  /// Get all tool definitions (regardless of enabled state)
  List<Map<String, dynamic>> get toolDefinitions {
    final tools = _builtinFactory.createBuiltinTools();
    return tools.map((t) => t.toJson()).toList();
  }
  
  /// Get enabled status for a tool
  Future<bool> isToolEnabled(String toolName) async {
    return await RepositoryFactory.config.isToolEnabled(toolName);
  }
  
  /// Toggle a tool's enabled state
  Future<void> toggleTool(String toolName) async {
    await RepositoryFactory.config.toggleTool(toolName);
  }
}
