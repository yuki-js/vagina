/// Represents supported per-speed-dial reasoning effort levels.
enum SpeedDialReasoningEffort { off, minimal, low, medium, high, xhigh }

/// Represents a speed dial entry (character preset with custom system prompt)
class SpeedDial {
  /// ID for the default speed dial (non-deletable, non-renameable)
  static const String defaultId = 'default';

  /// Default server registry voice-agent id used until the registry picker is wired.
  static const String defaultVoiceAgentId = 'voice-agent-prod';

  /// Default speed dial instance
  static SpeedDial get defaultSpeedDial => SpeedDial(
        id: defaultId,
        name: 'Default',
        systemPrompt: 'You are a helpful AI assistant.',
        description: 'Default voice assistant',
        voice: 'alloy',
        voiceAgentId: defaultVoiceAgentId,
        enabledTools: const {},
        reasoningEffort: SpeedDialReasoningEffort.off,
        toolChoiceRequired: false,
      );

  final String id;
  final String name;
  final String systemPrompt;
  final String? description;
  final String? iconEmoji; // Optional emoji icon
  final String voice;
  final String voiceAgentId;
  final Map<String, bool> enabledTools;
  final SpeedDialReasoningEffort reasoningEffort;
  final bool toolChoiceRequired;
  final DateTime? createdAt;

  /// Returns true if this is the default speed dial
  bool get isDefault => id == defaultId;

  const SpeedDial({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.description,
    this.iconEmoji,
    this.voice = 'alloy',
    this.voiceAgentId = defaultVoiceAgentId,
    this.enabledTools = const {},
    this.reasoningEffort = SpeedDialReasoningEffort.off,
    this.toolChoiceRequired = false,
    this.createdAt,
  });

  SpeedDial copyWith({
    String? id,
    String? name,
    String? systemPrompt,
    String? description,
    String? iconEmoji,
    String? voice,
    String? voiceAgentId,
    Map<String, bool>? enabledTools,
    SpeedDialReasoningEffort? reasoningEffort,
    bool? toolChoiceRequired,
    DateTime? createdAt,
  }) {
    return SpeedDial(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      description: description ?? this.description,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      voice: voice ?? this.voice,
      voiceAgentId: voiceAgentId ?? this.voiceAgentId,
      enabledTools: enabledTools ?? this.enabledTools,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      toolChoiceRequired: toolChoiceRequired ?? this.toolChoiceRequired,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'systemPrompt': systemPrompt,
      if (description != null) 'description': description,
      if (iconEmoji != null) 'iconEmoji': iconEmoji,
      'voice': voice,
      'voiceAgentId': voiceAgentId,
      'enabledTools': enabledTools,
      'reasoningEffort': reasoningEffort.name,
      'toolChoiceRequired': toolChoiceRequired,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  factory SpeedDial.fromJson(Map<String, dynamic> json) {
    return SpeedDial(
      id: json['id'] as String,
      name: json['name'] as String,
      systemPrompt: json['systemPrompt'] as String,
      description: json['description'] as String?,
      iconEmoji: json['iconEmoji'] as String?,
      voice: json['voice'] as String? ?? 'alloy',
      voiceAgentId: json['voiceAgentId'] as String? ?? defaultVoiceAgentId,
      enabledTools: json['enabledTools'] != null
          ? Map<String, bool>.from(json['enabledTools'] as Map)
          : const {}, // フォールバック: 空Map（キー不在=true規約により全ツール有効と同等）
      reasoningEffort: _reasoningEffortFromJson(json['reasoningEffort']),
      toolChoiceRequired: json['toolChoiceRequired'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  static SpeedDialReasoningEffort _reasoningEffortFromJson(Object? value) {
    if (value is String) {
      for (final effort in SpeedDialReasoningEffort.values) {
        if (effort.name == value) {
          return effort;
        }
      }
    }
    return SpeedDialReasoningEffort.off;
  }
}
