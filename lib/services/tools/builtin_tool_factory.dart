import 'base_tool.dart';
import 'builtin/builtin_tools.dart';
import '../storage_service.dart';
import '../notepad_service.dart';

/// Factory for creating built-in tools
class BuiltinToolFactory {
  final StorageService _storage;
  final NotepadService _notepadService;
  
  BuiltinToolFactory({
    required StorageService storage,
    required NotepadService notepadService,
  }) : _storage = storage, _notepadService = notepadService;
  
  /// Get all built-in tool names (for configuration)
  static const List<String> allToolNames = [
    'get_current_time',
    'memory_save',
    'memory_recall',
    'memory_delete',
    'calculator',
    'notepad_list_tabs',
    'notepad_get_metadata',
    'notepad_get_content',
    'notepad_close_tab',
    'document_overwrite',
    'document_patch',
    'document_read',
  ];
  
  /// Create all built-in tools
  List<BaseTool> createBuiltinTools() {
    return [
      GetCurrentTimeTool(),
      MemorySaveTool(storage: _storage),
      MemoryRecallTool(storage: _storage),
      MemoryDeleteTool(storage: _storage),
      CalculatorTool(),
      // Artifact management tools
      NotepadListTabsTool(notepadService: _notepadService),
      NotepadGetMetadataTool(notepadService: _notepadService),
      NotepadGetContentTool(notepadService: _notepadService),
      NotepadCloseTabTool(notepadService: _notepadService),
      // Document creation tools
      DocumentOverwriteTool(notepadService: _notepadService),
      DocumentPatchTool(notepadService: _notepadService),
      DocumentReadTool(notepadService: _notepadService),
    ];
  }
}
