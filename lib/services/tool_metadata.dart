library;

/// Flutter-facing tool metadata used for UI rendering and categorization.
///
/// This file is intentionally separate from the runtime tool system
/// (`lib/services/tools_runtime/` and `lib/tools/`) so those layers can stay
/// Flutter-free.

/// Tool category for UI grouping.
///
/// The enum `name` values are used as stable keys and should match
/// `ToolDefinition.categoryKey` values.
enum ToolCategory {
  system(displayName: 'システム', iconKey: 'settings'),
  calculation(displayName: '計算', iconKey: 'calculate'),
  memory(displayName: 'メモリ', iconKey: 'memory'),
  document(displayName: 'ドキュメント', iconKey: 'description'),
  notepad(displayName: 'ノート', iconKey: 'note'),
  mcp(displayName: 'MCP', iconKey: 'cloud'),
  custom(displayName: 'カスタム', iconKey: 'extension');

  final String displayName;
  final String iconKey;

  const ToolCategory({required this.displayName, required this.iconKey});
}

/// Tool source for UI labeling.
///
/// The enum `name` values are used as stable keys and should match
/// `ToolDefinition.sourceKey` values.
enum ToolSource {
  builtin(displayName: 'ビルトイン'),
  mcp(displayName: 'MCP'),
  custom(displayName: 'カスタム');

  final String displayName;

  const ToolSource({required this.displayName});
}

/// UI metadata for a tool.
class ToolMetadata {
  final String name;
  final String displayName;
  final String displayDescription;

  /// Tool description used for model/tooling.
  final String description;

  /// Stable icon key resolved by Flutter UI.
  final String? iconKey;

  final ToolCategory category;
  final ToolSource source;

  /// Optional MCP server URL when the tool comes from an MCP server.
  final String? mcpServerUrl;

  const ToolMetadata({
    required this.name,
    required this.displayName,
    required this.displayDescription,
    required this.description,
    required this.iconKey,
    required this.category,
    required this.source,
    required this.mcpServerUrl,
  });
}
