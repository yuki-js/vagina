class TextAgentDefinition {
  static const String defaultTextModelId = 'text-agent-prod';

  final String id;
  final String name;
  final String prompt;
  final String? description;
  final String textModelId;
  final Map<String, bool> enabledTools;
  final DateTime? createdAt;

  const TextAgentDefinition({
    required this.id,
    required this.name,
    required this.prompt,
    this.description,
    this.textModelId = defaultTextModelId,
    this.enabledTools = const {},
    this.createdAt,
  });

  TextAgentDefinition copyWith({
    String? id,
    String? name,
    String? prompt,
    String? description,
    String? textModelId,
    Map<String, bool>? enabledTools,
    DateTime? createdAt,
  }) {
    return TextAgentDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      description: description ?? this.description,
      textModelId: textModelId ?? this.textModelId,
      enabledTools: enabledTools ?? this.enabledTools,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
