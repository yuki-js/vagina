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
