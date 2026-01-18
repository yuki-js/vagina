import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/memory_repository.dart';

import 'notepad_service.dart';
import 'tool_metadata.dart';
import 'tools_runtime/simple_tool_factory.dart';
import 'tools_runtime/tool_context.dart';
import 'tools_runtime/tool_factory.dart';
import 'tools_runtime/tool_registry.dart' as runtime;
import 'tools_runtime/tool_runtime.dart';

import 'package:vagina/tools/builtin/builtin_tools.dart' as runtime_tools;

export 'tool_metadata.dart' show ToolMetadata, ToolCategory, ToolSource;

/// ツールサービス
///
/// アプリケーション全体のツール管理を担当する。
/// - ツールの有効/無効管理
/// - 将来のMCP対応の基盤
class ToolService {
  final NotepadService _notepadService;
  final MemoryRepository _memoryRepository;
  final ConfigRepository _configRepository;
  bool _initialized = false;

  /// Runtime tool factories keyed by toolKey.
  late final Map<String, ToolFactory> _runtimeToolFactories;

  ToolService({
    required NotepadService notepadService,
    required MemoryRepository memoryRepository,
    required ConfigRepository configRepository,
  })  : _notepadService = notepadService,
        _memoryRepository = memoryRepository,
        _configRepository = configRepository {
    _runtimeToolFactories = <String, ToolFactory>{
      runtime_tools.GetCurrentTimeTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.GetCurrentTimeTool()),
      runtime_tools.CalculatorTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.CalculatorTool()),
      runtime_tools.MemorySaveTool.toolKeyName: SimpleToolFactory(
        create: () => runtime_tools.MemorySaveTool(
          memoryRepository: _memoryRepository,
        ),
      ),
      runtime_tools.MemoryRecallTool.toolKeyName: SimpleToolFactory(
        create: () => runtime_tools.MemoryRecallTool(
          memoryRepository: _memoryRepository,
        ),
      ),
      runtime_tools.MemoryDeleteTool.toolKeyName: SimpleToolFactory(
        create: () => runtime_tools.MemoryDeleteTool(
          memoryRepository: _memoryRepository,
        ),
      ),
      runtime_tools.DocumentReadTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.DocumentReadTool()),
      runtime_tools.DocumentOverwriteTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.DocumentOverwriteTool()),
      runtime_tools.DocumentPatchTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.DocumentPatchTool()),
      runtime_tools.NotepadListTabsTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.NotepadListTabsTool()),
      runtime_tools.NotepadGetMetadataTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.NotepadGetMetadataTool()),
      runtime_tools.NotepadGetContentTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.NotepadGetContentTool()),
      runtime_tools.NotepadCloseTabTool.toolKeyName:
          SimpleToolFactory(create: () => runtime_tools.NotepadCloseTabTool()),
    };
  }
  
  /// サービスを初期化（ビルトインツールを登録）
  void initialize() {
    if (_initialized) return;

    // Legacy registry is removed; UI reads definitions from the runtime registry.
    _initialized = true;
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
  }) async {
    if (!_initialized) initialize();

    final allowList = toolNamesOverride?.toSet();
    final enabledTools = allowList == null
        ? await _configRepository.getEnabledTools()
        : const <String>[];

    final registry = runtime.ToolRegistry();

    for (final entry in _runtimeToolFactories.entries) {
      final toolName = entry.key;

      final shouldInclude = allowList != null
          ? allowList.contains(toolName)
          : (enabledTools.isEmpty || enabledTools.contains(toolName));

      if (!shouldInclude) continue;

      registry.registerFactory(entry.value);
    }

    final context = ToolContext(
      notepadService: _notepadService,
    );

    return registry.buildRuntimeForCall(context);
  }

  /// すべてのツール定義を取得（有効/無効問わず）
  List<Map<String, dynamic>> get toolDefinitions {
    if (!_initialized) initialize();

    final registry = runtime.ToolRegistry();
    for (final factory in _runtimeToolFactories.values) {
      registry.registerFactory(factory);
    }

    return registry
        .listDefinitions()
        .map((d) => d.toRealtimeJson())
        .toList(growable: false);
  }

  /// すべてのツールとメタデータを取得
  List<({String name, ToolMetadata metadata})> get allToolsWithMetadata {
    if (!_initialized) initialize();

    final registry = runtime.ToolRegistry();
    for (final factory in _runtimeToolFactories.values) {
      registry.registerFactory(factory);
    }

    return registry.listDefinitions().map((d) {
      final category = ToolCategory.values
          .where((c) => c.name == d.categoryKey)
          .cast<ToolCategory?>()
          .firstWhere((c) => c != null, orElse: () => null);

      final source = ToolSource.values
          .where((s) => s.name == d.sourceKey)
          .cast<ToolSource?>()
          .firstWhere((s) => s != null, orElse: () => null);

      return (
        name: d.toolKey,
        metadata: ToolMetadata(
          name: d.toolKey,
          displayName: d.displayName,
          displayDescription: d.displayDescription,
          description: d.description,
          iconKey: d.iconKey,
          category: category ?? ToolCategory.custom,
          source: source ?? ToolSource.custom,
          mcpServerUrl: d.mcpServerUrl,
        ),
      );
    }).toList(growable: false);
  }

  /// カテゴリ別にグループ化したツールを取得
  Map<ToolCategory, List<ToolMetadata>> get toolsByCategory {
    if (!_initialized) initialize();
    final result = <ToolCategory, List<ToolMetadata>>{};

    for (final entry in allToolsWithMetadata) {
      result.putIfAbsent(entry.metadata.category, () => <ToolMetadata>[])
          .add(entry.metadata);
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
    try {
      return allToolsWithMetadata
          .firstWhere((e) => e.name == name)
          .metadata;
    } catch (_) {
      return null;
    }
  }
}
