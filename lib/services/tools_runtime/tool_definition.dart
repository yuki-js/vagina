/// Unified tool metadata + realtime specification.
///
/// This type is Flutter-free and designed to be used by both UI and runtime
/// layers.
class ToolActivation {
  final bool alwaysAvailable;
  final List<String> extensions;

  const ToolActivation.always()
      : alwaysAvailable = true,
        extensions = const [];

  const ToolActivation.forExtensions(List<String> extensions)
      : alwaysAvailable = false,
        extensions = extensions;

  bool isEnabledForExtensions(Set<String> activeExtensions) {
    if (alwaysAvailable) {
      return true;
    }

    final normalizedActiveExtensions =
        activeExtensions.map((extension) => extension.toLowerCase()).toSet();

    for (final extension in extensions) {
      if (normalizedActiveExtensions.contains(extension.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'alwaysAvailable': alwaysAvailable,
      'extensions': extensions,
    };
  }

  static ToolActivation fromJson(Map<String, dynamic> json) {
    final always = json['alwaysAvailable'] as bool? ?? false;
    if (always) {
      return const ToolActivation.always();
    }

    final extensionsValue = json['extensions'] as List?;
    final extensions = extensionsValue == null
        ? const <String>[]
        : List<String>.from(extensionsValue);
    return ToolActivation.forExtensions(extensions);
  }
}

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

  /// Rule that defines when this tool should be active.
  final ToolActivation activation;

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
    this.activation = const ToolActivation.always(),
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
      'activation': activation.toJson(),
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
      activation: _parseActivation(json['activation']),
    );
  }

  static ToolActivation _parseActivation(dynamic rawActivation) {
    if (rawActivation is Map<String, dynamic>) {
      return ToolActivation.fromJson(rawActivation);
    }
    if (rawActivation is Map) {
      return ToolActivation.fromJson(Map<String, dynamic>.from(rawActivation));
    }
    return const ToolActivation.always();
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
