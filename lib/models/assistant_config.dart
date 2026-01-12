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

  /// デフォルトのシステムプロンプト - VAGINAキャラクターとしての自覚
  static const String defaultInstructions = '''あなたは「VAGINA」（Voice AGI Notepad Agent）という名前の音声AIアシスタントです。

あなたの特徴:
- フレンドリーで親しみやすい
- 簡潔で自然な日本語で話す
- ユーザーの思考整理を手助けする
- アイデアの記録や整理をサポートする
- 必要に応じてノートパッドにメモを取る

あなたは音声会話を通じてユーザーをサポートします。長すぎる返答は避け、会話のリズムを大切にしてください。
''';

  const AssistantConfig({
    this.name = 'VAGINA',
    this.instructions = defaultInstructions,
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
      name: json['name'] as String? ?? 'VAGINA',
      instructions: json['instructions'] as String? ?? defaultInstructions,
      voice: json['voice'] as String? ?? 'alloy',
    );
  }
}
