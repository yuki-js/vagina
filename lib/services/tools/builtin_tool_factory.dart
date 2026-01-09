import 'base_tool.dart';
import 'builtin/builtin_tools.dart';
import '../notepad_service.dart';
import '../../repositories/memory_repository.dart';

/// Factory for creating built-in tools
class BuiltinToolFactory {
  final MemoryRepository _memoryRepo;
  final NotepadService _notepadService;
  
  BuiltinToolFactory({
    required MemoryRepository memoryRepository,
    required NotepadService notepadService,
  }) : _memoryRepo = memoryRepository, _notepadService = notepadService;
  
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
      MemorySaveTool(memoryRepository: _memoryRepo),
      MemoryRecallTool(memoryRepository: _memoryRepo),
      MemoryDeleteTool(memoryRepository: _memoryRepo),
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
