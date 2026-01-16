import 'dart:convert';
import 'tool_metadata.dart';

/// ツールの基底クラス
///
/// すべてのツールはこのクラスを継承し、以下を実装する必要がある：
/// - [name]: ツールの一意識別子
/// - [description]: ツールの説明（AI向け、英語）
/// - [parameters]: パラメータのJSONスキーマ
/// - [execute]: ツールの実際の処理
/// - [metadata]: ツールのUIメタデータ
abstract class BaseTool {
  /// ツールの一意識別子
  String get name;

  /// ツールの説明（AI向け）
  String get description;

  /// パラメータのJSONスキーマ
  Map<String, dynamic> get parameters;

  /// ツールのUIメタデータ（表示名、アイコン、カテゴリなど）
  ToolMetadata get metadata;

  /// ツールを実行する
  /// 戻り値はJSON形式でエンコードされて返される
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments);

  /// ツールマネージャへの参照（登録時に設定される）
  ToolManagerRef? _managerRef;

  /// ツールマネージャを取得
  /// 他のツールを動的に登録/解除する際に使用
  ToolManagerRef? get manager => _managerRef;

  /// ツールマネージャへの参照を設定（内部使用）
  void setManagerRef(ToolManagerRef ref) {
    _managerRef = ref;
  }

  /// Realtime API用のJSON定義を生成
  Map<String, dynamic> toJson() {
    return {
      'type': 'function',
      'name': name,
      'description': description,
      'parameters': parameters,
    };
  }

  /// ツールを実行し、結果をフォーマットして返す
  Future<ToolExecutionResult> executeWithResult(
      String callId, String argumentsJson) async {
    try {
      final arguments = jsonDecode(argumentsJson) as Map<String, dynamic>;
      final result = await execute(arguments);
      return ToolExecutionResult(
        callId: callId,
        output: jsonEncode(result),
        success: true,
      );
    } catch (e) {
      return ToolExecutionResult(
        callId: callId,
        output: jsonEncode({'error': e.toString()}),
        success: false,
      );
    }
  }
}

/// ツール実行結果
class ToolExecutionResult {
  final String callId;
  final String output;
  final bool success;

  const ToolExecutionResult({
    required this.callId,
    required this.output,
    this.success = true,
  });
}

/// ツールマネージャへの参照インターフェース
/// ツールがマネージャと対話するための限定的なインターフェースを提供
abstract class ToolManagerRef {
  /// ツールを登録する
  void registerTool(BaseTool tool);

  /// ツールを登録解除する
  void unregisterTool(String name);

  /// ツールが登録されているか確認する
  bool hasTool(String name);

  /// 登録されたツール名の一覧を取得
  List<String> get registeredToolNames;
}
