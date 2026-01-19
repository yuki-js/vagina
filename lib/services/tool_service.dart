import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/tools/tools.dart';

import 'tool_metadata.dart';

export 'tool_metadata.dart' show ToolMetadata, ToolCategory, ToolSource;

/// ツールサービス
///
/// アプリケーション全体のツール管理を担当する。
/// - ツールの有効/無効管理
/// - 将来のMCP対応の基盤
class ToolService {
  final ConfigRepository _configRepository;

  ToolService({
    required ConfigRepository configRepository,
  }) : _configRepository = configRepository {
    setTools(toolbox);
  }

  final Map<String, Tool> _tools = {};

  void setTools(List<Tool> tools) {
    for (var tool in tools) {
      setTool(tool);
    }
  }

  void setTool(Tool tool) {
    final String key = tool.definition.toolKey;
    _tools[key] = tool;
  }

  List<ToolMetadata> get registeredToolMeta {
    return _tools.values
        .map((tool) => ToolMetadata(
            name: tool.definition.toolKey,
            displayName: tool.definition.displayName,
            displayDescription: tool.definition.displayDescription,
            description: tool.definition.description,
            iconKey: tool.definition.iconKey,
            category: ToolCategory.fromKey(tool.definition.categoryKey),
            source: ToolSource.fromKey(tool.definition.sourceKey),
            mcpServerUrl: tool.definition.mcpServerUrl))
        .toList();
  }

  Tool? getToolByKey(String toolKey) {
    return _tools[toolKey];
  }

  List<Tool> get registeredTools {
    return _tools.values.toList();
  }

  Future<List<Tool>> getEnabledTools() async {
    List<Tool> enabledTools = [];
    for (var tool in _tools.values) {
      final isEnabled =
          await _configRepository.isToolEnabled(tool.definition.toolKey);
      if (isEnabled) {
        enabledTools.add(tool);
      }
    }
    return enabledTools;
  }

  Future<List<Tool>> getRegisteredTools() async {
    return _tools.values.toList();
  }
}
