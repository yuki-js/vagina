/// スキルのカテゴリ
enum SkillCategory {
  finance(displayName: '財務・会計', iconKey: 'account_balance'),
  document(displayName: '文書・記録', iconKey: 'description'),
  communication(displayName: 'コミュニケーション', iconKey: 'chat'),
  productivity(displayName: '生産性', iconKey: 'flash_on'),
  research(displayName: 'リサーチ', iconKey: 'search'),
  custom(displayName: 'カスタム', iconKey: 'extension');

  final String displayName;
  final String iconKey;

  const SkillCategory({required this.displayName, required this.iconKey});

  /// キー文字列からカテゴリを取得する（未知のキーは [custom] にフォールバック）
  static SkillCategory fromKey(String key) {
    return SkillCategory.values.firstWhere(
      (c) => c.name == key,
      orElse: () => SkillCategory.custom,
    );
  }
}

/// スキル - ツールと集中した指示を組み合わせた再利用可能なAIケイパビリティを表す
class Skill {
  final String id;
  final String name;
  final String description;

  /// スキルがアクティブな際に追加されるシステムプロンプト
  final String systemPromptAddition;

  /// このスキルが有効化するツールキーの一覧
  final List<String> enabledToolKeys;

  final SkillCategory category;
  final String? iconEmoji; // オプションの絵文字アイコン
  final DateTime createdAt;
  final DateTime updatedAt;

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPromptAddition,
    required this.enabledToolKeys,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.iconEmoji,
  });

  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPromptAddition,
    List<String>? enabledToolKeys,
    SkillCategory? category,
    String? iconEmoji,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPromptAddition: systemPromptAddition ?? this.systemPromptAddition,
      enabledToolKeys: enabledToolKeys ?? this.enabledToolKeys,
      category: category ?? this.category,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'systemPromptAddition': systemPromptAddition,
      'enabledToolKeys': enabledToolKeys,
      'category': category.name,
      if (iconEmoji != null) 'iconEmoji': iconEmoji,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      systemPromptAddition: json['systemPromptAddition'] as String,
      enabledToolKeys: json['enabledToolKeys'] != null
          ? List<String>.from(json['enabledToolKeys'] as List)
          : const [], // フォールバック: 空リスト
      category: SkillCategory.fromKey(json['category'] as String? ?? ''),
      iconEmoji: json['iconEmoji'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
