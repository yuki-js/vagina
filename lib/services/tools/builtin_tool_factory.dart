import 'base_tool.dart';
import 'builtin/builtin_tools.dart';
import 'package:vagina/services/notepad_service.dart';
import 'package:vagina/interfaces/memory_repository.dart';

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

  /// Returns builders that create **fresh** legacy tool instances.
  ///
  /// This is used by the new per-call runtime layer so tools are not reused
  /// across calls.
  Map<String, BaseTool Function()> createBuiltinToolBuilders() {
    return <String, BaseTool Function()>{
      'get_current_time': () => GetCurrentTimeTool(),
      'memory_save': () => MemorySaveTool(memoryRepository: _memoryRepo),
      'memory_recall': () => MemoryRecallTool(memoryRepository: _memoryRepo),
      'memory_delete': () => MemoryDeleteTool(memoryRepository: _memoryRepo),
      'calculator': () => CalculatorTool(),
      // ノートパッド管理ツール
      'notepad_list_tabs': () => NotepadListTabsTool(notepadService: _notepadService),
      'notepad_get_metadata': () => NotepadGetMetadataTool(notepadService: _notepadService),
      'notepad_get_content': () => NotepadGetContentTool(notepadService: _notepadService),
      'notepad_close_tab': () => NotepadCloseTabTool(notepadService: _notepadService),
      // ドキュメント作成ツール
      'document_overwrite': () => DocumentOverwriteTool(notepadService: _notepadService),
      'document_patch': () => DocumentPatchTool(notepadService: _notepadService),
      'document_read': () => DocumentReadTool(notepadService: _notepadService),
    };
  }

  /// すべてのビルトインツールを生成
  ///
  /// Note: These instances may be stored in legacy registries and should not be
  /// reused for per-call execution. Use [createBuiltinToolBuilders] for the
  /// runtime layer.
  List<BaseTool> createBuiltinTools() {
    final builders = createBuiltinToolBuilders();
    return builders.values.map((b) => b()).toList(growable: false);
  }
}
