import 'base_tool.dart';
import 'builtin/builtin_tools.dart';
import '../notepad_service.dart';
import '../../interfaces/memory_repository.dart';

/// ビルトインツールのファクトリ
class BuiltinToolFactory {
  final MemoryRepository _memoryRepo;
  final NotepadService _notepadService;

  BuiltinToolFactory({
    required MemoryRepository memoryRepository,
    required NotepadService notepadService,
  })  : _memoryRepo = memoryRepository,
        _notepadService = notepadService;

  /// すべてのビルトインツール名（設定用）
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

  /// すべてのビルトインツールを生成
  List<BaseTool> createBuiltinTools() {
    return [
      GetCurrentTimeTool(),
      MemorySaveTool(memoryRepository: _memoryRepo),
      MemoryRecallTool(memoryRepository: _memoryRepo),
      MemoryDeleteTool(memoryRepository: _memoryRepo),
      CalculatorTool(),
      // ノートパッド管理ツール
      NotepadListTabsTool(notepadService: _notepadService),
      NotepadGetMetadataTool(notepadService: _notepadService),
      NotepadGetContentTool(notepadService: _notepadService),
      NotepadCloseTabTool(notepadService: _notepadService),
      // ドキュメント作成ツール
      DocumentOverwriteTool(notepadService: _notepadService),
      DocumentPatchTool(notepadService: _notepadService),
      DocumentReadTool(notepadService: _notepadService),
    ];
  }
}
