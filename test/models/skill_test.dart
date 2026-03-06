import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/skill.dart';

void main() {
  final createdAt = DateTime(2024, 1, 1, 12, 0, 0);
  final updatedAt = DateTime(2024, 1, 2, 12, 0, 0);

  group('Skill Model', () {
    test('toJson() serialises all fields correctly', () {
      final skill = Skill(
        id: 'skill-1',
        name: '確定申告サポート',
        description: '確定申告の計算・書類作成を支援します',
        systemPromptAddition: '日本の税制に従い正確な申告書を作成してください',
        enabledToolKeys: const ['calculator', 'document_write'],
        category: SkillCategory.finance,
        iconEmoji: '💹',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = skill.toJson();

      expect(json['id'], 'skill-1');
      expect(json['name'], '確定申告サポート');
      expect(json['description'], '確定申告の計算・書類作成を支援します');
      expect(json['systemPromptAddition'], '日本の税制に従い正確な申告書を作成してください');
      expect(json['enabledToolKeys'], ['calculator', 'document_write']);
      expect(json['category'], 'finance');
      expect(json['iconEmoji'], '💹');
      expect(json['createdAt'], createdAt.toIso8601String());
      expect(json['updatedAt'], updatedAt.toIso8601String());
    });

    test('toJson() omits iconEmoji when null', () {
      final skill = Skill(
        id: 'skill-2',
        name: 'No Emoji',
        description: '',
        systemPromptAddition: '',
        enabledToolKeys: const [],
        category: SkillCategory.custom,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = skill.toJson();
      expect(json.containsKey('iconEmoji'), false);
    });

    test('fromJson() deserialises all fields correctly', () {
      final json = {
        'id': 'skill-3',
        'name': '文書作成',
        'description': 'ドキュメントを自動生成します',
        'systemPromptAddition': '丁寧な敬語を使用してください',
        'enabledToolKeys': ['document_read', 'document_write'],
        'category': 'document',
        'iconEmoji': '📄',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

      final skill = Skill.fromJson(json);

      expect(skill.id, 'skill-3');
      expect(skill.name, '文書作成');
      expect(skill.description, 'ドキュメントを自動生成します');
      expect(skill.systemPromptAddition, '丁寧な敬語を使用してください');
      expect(skill.enabledToolKeys, ['document_read', 'document_write']);
      expect(skill.category, SkillCategory.document);
      expect(skill.iconEmoji, '📄');
      expect(skill.createdAt, createdAt);
      expect(skill.updatedAt, updatedAt);
    });

    test('fromJson() falls back to empty list when enabledToolKeys is absent',
        () {
      final json = {
        'id': 'skill-4',
        'name': 'Legacy',
        'description': '',
        'systemPromptAddition': '',
        'category': 'custom',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

      final skill = Skill.fromJson(json);
      expect(skill.enabledToolKeys, isEmpty);
    });

    test('fromJson() falls back to custom category for unknown key', () {
      final json = {
        'id': 'skill-5',
        'name': 'Unknown',
        'description': '',
        'systemPromptAddition': '',
        'enabledToolKeys': <String>[],
        'category': 'nonexistent_category',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

      final skill = Skill.fromJson(json);
      expect(skill.category, SkillCategory.custom);
    });

    test('copyWith() returns modified copy without affecting original', () {
      final original = Skill(
        id: 'skill-6',
        name: 'Original',
        description: 'desc',
        systemPromptAddition: 'prompt',
        enabledToolKeys: const ['tool_a'],
        category: SkillCategory.productivity,
        iconEmoji: '⚡',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final copy = original.copyWith(
        name: 'Modified',
        enabledToolKeys: ['tool_a', 'tool_b'],
      );

      expect(copy.id, original.id);
      expect(copy.name, 'Modified');
      expect(copy.enabledToolKeys, ['tool_a', 'tool_b']);
      expect(copy.category, SkillCategory.productivity);
      expect(copy.iconEmoji, '⚡');

      // Original is unchanged
      expect(original.name, 'Original');
      expect(original.enabledToolKeys, ['tool_a']);
    });

    test('round-trip serialisation preserves all fields', () {
      final original = Skill(
        id: 'skill-7',
        name: 'Round Trip',
        description: 'Full round-trip test',
        systemPromptAddition: 'Round-trip system prompt',
        enabledToolKeys: const ['tool_x', 'tool_y', 'tool_z'],
        category: SkillCategory.research,
        iconEmoji: '🔬',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final restored = Skill.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.systemPromptAddition, original.systemPromptAddition);
      expect(restored.enabledToolKeys, original.enabledToolKeys);
      expect(restored.category, original.category);
      expect(restored.iconEmoji, original.iconEmoji);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });

  group('SkillCategory', () {
    test('fromKey() returns the matching category', () {
      expect(SkillCategory.fromKey('finance'), SkillCategory.finance);
      expect(SkillCategory.fromKey('document'), SkillCategory.document);
      expect(
          SkillCategory.fromKey('communication'), SkillCategory.communication);
      expect(SkillCategory.fromKey('productivity'), SkillCategory.productivity);
      expect(SkillCategory.fromKey('research'), SkillCategory.research);
      expect(SkillCategory.fromKey('custom'), SkillCategory.custom);
    });

    test('fromKey() falls back to custom for unknown key', () {
      expect(SkillCategory.fromKey(''), SkillCategory.custom);
      expect(SkillCategory.fromKey('unknown'), SkillCategory.custom);
    });

    test('all categories have non-empty displayName and iconKey', () {
      for (final category in SkillCategory.values) {
        expect(category.displayName, isNotEmpty,
            reason: '${category.name} has empty displayName');
        expect(category.iconKey, isNotEmpty,
            reason: '${category.name} has empty iconKey');
      }
    });
  });
}
