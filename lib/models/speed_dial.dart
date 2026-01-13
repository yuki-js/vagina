/// Represents a speed dial entry (character preset with custom system prompt)
class SpeedDial {
  final String id;
  final String name;
  final String systemPrompt;
  final String? iconEmoji; // Optional emoji icon
  final String voice;
  final DateTime? createdAt;

  const SpeedDial({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.iconEmoji,
    this.voice = 'alloy',
    this.createdAt,
  });

  SpeedDial copyWith({
    String? id,
    String? name,
    String? systemPrompt,
    String? iconEmoji,
    String? voice,
    DateTime? createdAt,
  }) {
    return SpeedDial(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      voice: voice ?? this.voice,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'systemPrompt': systemPrompt,
      if (iconEmoji != null) 'iconEmoji': iconEmoji,
      'voice': voice,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  factory SpeedDial.fromJson(Map<String, dynamic> json) {
    return SpeedDial(
      id: json['id'] as String,
      name: json['name'] as String,
      systemPrompt: json['systemPrompt'] as String,
      iconEmoji: json['iconEmoji'] as String?,
      voice: json['voice'] as String? ?? 'alloy',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}
