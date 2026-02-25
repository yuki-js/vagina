/// Unified tool metadata + realtime specification.
///
/// This type is Flutter-free and designed to be used by both UI and runtime
/// layers.
class ToolDefinition {
  /// Stable identifier used by the runtime and sent to the Realtime API.
  final String toolKey;

  /// Human-facing display name (e.g. Japanese UI label).
  final String displayName;

  /// Human-facing description (e.g. Japanese UI description).
  final String displayDescription;

  /// Category identifier (UI/runtime).
  final String categoryKey;

  /// Icon identifier (UI/runtime).
  final String iconKey;

  /// Source identifier (e.g. builtin/mcp/custom).
  final String sourceKey;

  /// Publisher/author
  /// Tools from the same publisher can share some resources/configurations.
  final String publishedBy;

  /// Optional MCP server URL (if this tool is backed by an MCP server).
  final String? mcpServerUrl;

  /// AI-facing tool description (English).
  final String description;

  /// JSON schema for tool parameters.
  ///
  /// Kept as a raw map for compatibility with existing code.
  final Map<String, dynamic> parametersSchema;

  const ToolDefinition({
    required this.toolKey,
    required this.displayName,
    required this.displayDescription,
    required this.categoryKey,
    required this.iconKey,
    required this.sourceKey,
    required this.publishedBy,
    this.mcpServerUrl,
    required this.description,
    required this.parametersSchema,
  });

  Map<String, dynamic> toJson() {
    return {
      'toolKey': toolKey,
      'displayName': displayName,
      'displayDescription': displayDescription,
      'categoryKey': categoryKey,
      'iconKey': iconKey,
      'sourceKey': sourceKey,
      'publishedBy': publishedBy,
      'mcpServerUrl': mcpServerUrl,
      'description': description,
      'parametersSchema': parametersSchema,
    };
  }

  static ToolDefinition fromJson(Map<String, dynamic> json) {
    return ToolDefinition(
      toolKey: json['toolKey'] as String,
      displayName: json['displayName'] as String,
      displayDescription: json['displayDescription'] as String,
      categoryKey: json['categoryKey'] as String,
      iconKey: json['iconKey'] as String,
      sourceKey: json['sourceKey'] as String,
      publishedBy: json['publishedBy'] as String,
      mcpServerUrl: json['mcpServerUrl'] as String?,
      description: json['description'] as String,
      parametersSchema:
          Map<String, dynamic>.from(json['parametersSchema'] as Map),
    );
  }

  /// Realtime API compatible tool definition (function tool).
  Map<String, Object> toRealtimeJson() {
    return {
      'type': 'function',
      'name': toolKey,
      'description': description,
      'parameters': parametersSchema,
    };
  }
}
