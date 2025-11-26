/// Configuration for the AI assistant
class AssistantConfig {
  /// The name of the assistant
  final String name;

  /// The system instructions for the assistant
  final String instructions;

  /// The voice to use for the assistant
  final String voice;

  /// Available voices for the assistant
  static const List<String> availableVoices = [
    'alloy',
    'echo',
    'shimmer',
  ];

  const AssistantConfig({
    this.name = 'VAGINA Assistant',
    this.instructions = '''You are a helpful voice assistant. 
Be concise and natural in your responses.
Speak in a friendly and professional manner.
''',
    this.voice = 'alloy',
  });

  AssistantConfig copyWith({
    String? name,
    String? instructions,
    String? voice,
  }) {
    return AssistantConfig(
      name: name ?? this.name,
      instructions: instructions ?? this.instructions,
      voice: voice ?? this.voice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'instructions': instructions,
      'voice': voice,
    };
  }

  factory AssistantConfig.fromJson(Map<String, dynamic> json) {
    return AssistantConfig(
      name: json['name'] as String? ?? 'VAGINA Assistant',
      instructions: json['instructions'] as String? ?? '',
      voice: json['voice'] as String? ?? 'alloy',
    );
  }
}
