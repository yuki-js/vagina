import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/memory_repository.dart';

import 'notepad_service.dart';
import 'tools/base_tool.dart' show ToolManagerRef;
import 'tools/builtin_tool_factory.dart';
import 'tools/tool_manager.dart';
import 'tools/tool_metadata.dart';
import 'tools/tool_registry.dart';
import 'tools_runtime/legacy_tool_factory.dart';
import 'tools_runtime/notepad_backend.dart';
import 'tools_runtime/tool_context.dart';
import 'tools_runtime/tool_registry.dart' as runtime;
import 'tools_runtime/tool_runtime.dart';

export 'tools/base_tool.dart' show BaseTool, ToolExecutionResult, ToolManagerRef;
export 'tools/tool_manager.dart' show ToolManager;
export 'tools/tool_registry.dart'
    show ToolRegistry, ToolRegistryEvent, ToolRegistryEventType;
export 'tools/tool_metadata.dart' show ToolMetadata, ToolCategory, ToolSource;

/// ツールサービス
///
/// アプリケーション全体のツール管理を担当する。
/// - ビルトインツールの初期化
/// - セッションスコープのToolManager生成
/// - ツールの有効/無効管理
/// - 将来のMCP対応の基盤
class ToolService {
  final NotepadService _notepadService;
  final MemoryRepository _memoryRepository;
  final ConfigRepository _configRepository;
  late final BuiltinToolFactory _builtinFactory;
  final ToolRegistry _registry = ToolRegistry();
  bool _initialized = false;

  ToolService({
    required NotepadService notepadService,
    required MemoryRepository memoryRepository,
    required ConfigRepository configRepository,
  })  : _notepadService = notepadService,
        _memoryRepository = memoryRepository,
        _configRepository = configRepository {
    _builtinFactory = BuiltinToolFactory(
      memoryRepository: _memoryRepository,
      notepadService: _notepadService,
    );
  }
  
  /// ツールレジストリを取得
  ToolRegistry get registry => _registry;
  
  /// サービスを初期化（ビルトインツールを登録）
  void initialize() {
    if (_initialized) return;
    
    // ビルトインツールを登録
    // 各ツールは自身のmetadataゲッターを持つため、それを使用
    final tools = _builtinFactory.createBuiltinTools();
    for (final tool in tools) {
      _registry.registerTool(tool, tool.metadata);
    }
    
    _initialized = true;
  }
  
  /// セッションスコープのToolManagerを生成
  /// 通話開始時に呼び出される
  Future<ToolManager> createToolManager({void Function()? onToolsChanged}) async {
    // 未初期化なら初期化
    if (!_initialized) initialize();
    
    final manager = ToolManager(onToolsChanged: onToolsChanged);
    final allTools = _registry.getAllTools();
    final enabledTools = await _configRepository.getEnabledTools();
    
    // 有効なツールのみを登録
    for (final entry in allTools) {
      final isEnabled = enabledTools.isEmpty || enabledTools.contains(entry.tool.name);
      if (isEnabled) {
        manager.registerTool(entry.tool);
      }
    }
    
    return manager;
  }

  /// Creates a per-call [ToolRuntime] with fresh tool instances.
  ///
  /// If [toolNamesOverride] is provided, it is treated as the source-of-truth
  /// for which tools should be present (e.g. when mirroring a live session's
  /// tool manager state).
  ///
  /// Otherwise, current enabled/disabled config semantics are used:
  /// - enabledTools empty => all tools enabled
  /// - enabledTools non-empty => only listed tools enabled
  Future<ToolRuntime> createToolRuntime({
    Iterable<String>? toolNamesOverride,
    ToolManagerRef? managerRef,
  }) async {
    if (!_initialized) initialize();

    final allowList = toolNamesOverride?.toSet();
    final enabledTools = allowList == null
        ? await _configRepository.getEnabledTools()
        : const <String>[];

    final registry = runtime.ToolRegistry();
    final builders = _builtinFactory.createBuiltinToolBuilders();

    for (final entry in builders.entries) {
      final toolName = entry.key;

      final shouldInclude = allowList != null
          ? allowList.contains(toolName)
          : (enabledTools.isEmpty || enabledTools.contains(toolName));

      if (!shouldInclude) continue;

      registry.registerFactory(
        LegacyToolFactory(
          createLegacy: entry.value,
          managerRef: managerRef,
        ),
      );
    }

    final context = ToolContext(
      notepadBackend: NotepadBackend(initialTabs: _notepadService.tabs),
    );

    return registry.buildRuntimeForCall(context);
  }

  /// すべてのツール定義を取得（有効/無効問わず）
  List<Map<String, dynamic>> get toolDefinitions {
    if (!_initialized) initialize();
    return _registry.getToolDefinitions();
  }
  
  /// すべてのツールとメタデータを取得
  List<({String name, ToolMetadata metadata})> get allToolsWithMetadata {
    if (!_initialized) initialize();
    return _registry.getAllTools()
        .map((t) => (name: t.tool.name, metadata: t.metadata))
        .toList();
  }
  
  /// カテゴリ別にグループ化したツールを取得
  Map<ToolCategory, List<ToolMetadata>> get toolsByCategory {
    if (!_initialized) initialize();
    final result = <ToolCategory, List<ToolMetadata>>{};
    for (final entry in _registry.getAllTools()) {
      result.putIfAbsent(entry.metadata.category, () => []).add(entry.metadata);
    }
    return result;
  }
  
  /// ツールの有効状態を取得
  Future<bool> isToolEnabled(String toolName) async {
    return await _configRepository.isToolEnabled(toolName);
  }
  
  /// ツールの有効/無効を切り替え
  Future<void> toggleTool(String toolName) async {
    await _configRepository.toggleTool(toolName);
  }
  
  /// ツールメタデータを取得
  ToolMetadata? getToolMetadata(String name) {
    if (!_initialized) initialize();
    return _registry.getMetadata(name);
  }
}
