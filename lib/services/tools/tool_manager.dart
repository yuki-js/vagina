import 'base_tool.dart';
import 'package:vagina/services/log_service.dart';

/// セッションスコープのツールマネージャ
/// 
/// 通話開始時に作成され、通話終了時に破棄される。
/// ツールの登録/解除を管理し、API用のツール定義を提供する。
class ToolManager implements ToolManagerRef {
  static const _tag = 'ToolManager';
  
  /// ツール名からツールインスタンスへのマップ
  final Map<String, BaseTool> _tools = {};
  
  /// ツール変更時のコールバック（セッション設定更新用）
  final void Function()? onToolsChanged;
  
  ToolManager({this.onToolsChanged});

  @override
  void registerTool(BaseTool tool) {
    if (_tools.containsKey(tool.name)) {
      logService.warn(_tag, 'ツール ${tool.name} を上書き登録');
    }
    tool.setManagerRef(this);
    _tools[tool.name] = tool;
    logService.info(_tag, 'ツール登録: ${tool.name}');
    onToolsChanged?.call();
  }
  
  /// 複数のツールを一度に登録
  void registerTools(List<BaseTool> tools) {
    for (final tool in tools) {
      registerTool(tool);
    }
  }

  @override
  void unregisterTool(String name) {
    if (_tools.containsKey(name)) {
      _tools.remove(name);
      logService.info(_tag, 'ツール登録解除: $name');
      onToolsChanged?.call();
    } else {
      logService.warn(_tag, '未登録ツールの解除試行: $name');
    }
  }

  @override
  bool hasTool(String name) => _tools.containsKey(name);

  @override
  List<String> get registeredToolNames => _tools.keys.toList();
  
  /// Realtime APIセッション設定用のツール定義を取得
  List<Map<String, dynamic>> get toolDefinitions {
    return _tools.values.map((t) => t.toJson()).toList();
  }
  
  /// ツールを名前で実行
  Future<ToolExecutionResult> executeTool(String callId, String name, String argumentsJson) async {
    final tool = _tools[name];
    if (tool == null) {
      logService.error(_tag, '不明なツール: $name');
      return ToolExecutionResult(
        callId: callId,
        output: '{"error": "不明なツール: $name"}',
        success: false,
      );
    }
    
    logService.info(_tag, 'ツール実行: $name');
    final result = await tool.executeWithResult(callId, argumentsJson);
    if (result.success) {
      logService.info(_tag, 'ツール $name 成功');
    } else {
      logService.error(_tag, 'ツール $name 失敗');
    }
    return result;
  }
  
  /// 登録されたツール数を取得
  int get toolCount => _tools.length;
  
  /// マネージャを破棄してリソースをクリーンアップ
  void dispose() {
    _tools.clear();
    logService.info(_tag, 'ToolManager破棄');
  }
}
