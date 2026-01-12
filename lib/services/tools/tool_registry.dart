import 'dart:async';
import 'base_tool.dart';
import 'tool_metadata.dart';
import '../log_service.dart';

/// ツールレジストリ
/// 
/// アプリケーション全体でツールを一元管理する。
/// - ビルトインツールの登録
/// - MCPツールの動的登録（将来）
/// - カスタムツールの登録（将来）
/// - ツールメタデータの管理
class ToolRegistry {
  static const _tag = 'ToolRegistry';
  
  /// シングルトンインスタンス
  static final ToolRegistry _instance = ToolRegistry._internal();
  factory ToolRegistry() => _instance;
  ToolRegistry._internal();
  
  /// 登録されたツール（名前 → ツールインスタンス）
  final Map<String, BaseTool> _tools = {};
  
  /// ツールメタデータ（名前 → メタデータ）
  final Map<String, ToolMetadata> _metadata = {};
  
  /// ツール変更通知用ストリーム
  final StreamController<ToolRegistryEvent> _eventController =
      StreamController<ToolRegistryEvent>.broadcast();
  
  /// ツール変更イベントストリーム
  Stream<ToolRegistryEvent> get events => _eventController.stream;
  
  /// 登録されたツール名一覧
  List<String> get toolNames => _tools.keys.toList();
  
  /// 登録されたツール数
  int get toolCount => _tools.length;
  
  /// ツールを登録する
  void registerTool(BaseTool tool, ToolMetadata metadata) {
    if (_tools.containsKey(tool.name)) {
      logService.warn(_tag, 'ツール ${tool.name} を上書き登録');
    }
    
    _tools[tool.name] = tool;
    _metadata[tool.name] = metadata;
    
    logService.info(_tag, 'ツール登録: ${tool.name} (${metadata.category.displayName})');
    _eventController.add(ToolRegistryEvent(
      type: ToolRegistryEventType.registered,
      toolName: tool.name,
    ));
  }
  
  /// ツールを登録解除する
  void unregisterTool(String name) {
    if (_tools.containsKey(name)) {
      _tools.remove(name);
      _metadata.remove(name);
      
      logService.info(_tag, 'ツール登録解除: $name');
      _eventController.add(ToolRegistryEvent(
        type: ToolRegistryEventType.unregistered,
        toolName: name,
      ));
    } else {
      logService.warn(_tag, '未登録ツールの解除試行: $name');
    }
  }
  
  /// ツールが登録されているか確認
  bool hasTool(String name) => _tools.containsKey(name);
  
  /// ツールを取得
  BaseTool? getTool(String name) => _tools[name];
  
  /// ツールメタデータを取得
  ToolMetadata? getMetadata(String name) => _metadata[name];
  
  /// すべてのツールとメタデータを取得
  List<({BaseTool tool, ToolMetadata metadata})> getAllTools() {
    return _tools.entries
        .where((e) => _metadata.containsKey(e.key))
        .map((e) => (tool: e.value, metadata: _metadata[e.key]!))
        .toList();
  }
  
  /// カテゴリでツールをフィルタ
  List<({BaseTool tool, ToolMetadata metadata})> getToolsByCategory(ToolCategory category) {
    return getAllTools().where((t) => t.metadata.category == category).toList();
  }
  
  /// ソースでツールをフィルタ
  List<({BaseTool tool, ToolMetadata metadata})> getToolsBySource(ToolSource source) {
    return getAllTools().where((t) => t.metadata.source == source).toList();
  }
  
  /// ツールのJSON定義を取得（API送信用）
  List<Map<String, dynamic>> getToolDefinitions() {
    return _tools.values.map((t) => t.toJson()).toList();
  }
  
  /// 指定ツールのみのJSON定義を取得
  List<Map<String, dynamic>> getToolDefinitionsFor(List<String> names) {
    return names
        .where((name) => _tools.containsKey(name))
        .map((name) => _tools[name]!.toJson())
        .toList();
  }
  
  /// すべてのツールを登録解除
  void clear() {
    final names = _tools.keys.toList();
    for (final name in names) {
      unregisterTool(name);
    }
    logService.info(_tag, 'すべてのツールを登録解除');
  }
  
  /// リソースを解放
  void dispose() {
    _eventController.close();
    clear();
  }
}

/// ツールレジストリのイベント種別
enum ToolRegistryEventType {
  registered,
  unregistered,
  updated,
}

/// ツールレジストリのイベント
class ToolRegistryEvent {
  final ToolRegistryEventType type;
  final String toolName;
  
  const ToolRegistryEvent({
    required this.type,
    required this.toolName,
  });
}
