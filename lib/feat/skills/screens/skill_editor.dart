import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/shared/widgets/tool_config_section.dart';
import 'package:vagina/feat/skills/state/skill_providers.dart';
import 'package:vagina/feat/speed_dial/widgets/emoji_picker.dart';
import 'package:vagina/models/skill.dart';

/// スキル作成・編集画面
///
/// - [skill] が `null` の場合は新規作成モード
/// - [skill] が非 `null` の場合は編集モード
///
/// 保存・削除後は `skillsProvider` を invalidate してからポップする。
class SkillEditorScreen extends ConsumerStatefulWidget {
  final Skill? skill;

  const SkillEditorScreen({super.key, this.skill});

  @override
  ConsumerState<SkillEditorScreen> createState() => _SkillEditorScreenState();
}

class _SkillEditorScreenState extends ConsumerState<SkillEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _systemPromptController;
  late String _selectedEmoji;
  late SkillCategory _selectedCategory;

  /// ToolConfigSection が期待する `Map<String, bool>` 形式のツール状態
  ///
  /// Skill モデルの `enabledToolKeys: List<String>` を変換して保持する。
  /// キー不在 = 無効 (新規作成時はすべて false からスタート)
  late Map<String, bool> _enabledTools;

  bool get _isNewSkill => widget.skill == null;

  @override
  void initState() {
    super.initState();
    final skill = widget.skill;

    if (skill == null) {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _systemPromptController = TextEditingController();
      _selectedEmoji = '🔧';
      _selectedCategory = SkillCategory.custom;
      _enabledTools = {};
    } else {
      _nameController = TextEditingController(text: skill.name);
      _descriptionController = TextEditingController(text: skill.description);
      _systemPromptController =
          TextEditingController(text: skill.systemPromptAddition);
      _selectedEmoji = skill.iconEmoji ?? '🔧';
      _selectedCategory = skill.category;
      // enabledToolKeys (List<String>) -> Map<String, bool>
      // 明示的に有効なキーだけ true、その他は false
      _enabledTools = {
        for (final key in skill.enabledToolKeys) key: true,
      };
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _selectEmoji() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: EmojiPicker(
            selectedEmoji: _selectedEmoji,
            onEmojiSelected: (emoji) {
              setState(() => _selectedEmoji = emoji);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前を入力してください')),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    final systemPromptAddition = _systemPromptController.text.trim();
    final enabledToolKeys =
        _enabledTools.entries.where((e) => e.value).map((e) => e.key).toList();

    final now = DateTime.now();
    final skill = Skill(
      id: _isNewSkill
          ? now.millisecondsSinceEpoch.toString()
          : widget.skill!.id,
      name: name,
      description: description,
      systemPromptAddition: systemPromptAddition,
      enabledToolKeys: enabledToolKeys,
      category: _selectedCategory,
      iconEmoji: _selectedEmoji,
      createdAt: _isNewSkill ? now : widget.skill!.createdAt,
      updatedAt: now,
    );

    final repo = ref.read(skillRepositoryProvider);
    if (_isNewSkill) {
      await repo.save(skill);
    } else {
      await repo.update(skill);
    }

    ref.invalidate(skillsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNewSkill ? 'スキルを追加しました' : 'スキルを更新しました'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('このスキルを削除しますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(skillRepositoryProvider).delete(widget.skill!.id);
      ref.invalidate(skillsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isNewSkill ? 'スキルを追加' : 'スキルを編集'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.lightTextPrimary,
        elevation: 0,
        actions: [
          if (!_isNewSkill)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              color: AppTheme.errorColor,
              tooltip: '削除',
            ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
            tooltip: '保存',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Emoji ──────────────────────────────────────────────────────
            _buildEmojiCard(),
            const SizedBox(height: 16),

            // ── Name ───────────────────────────────────────────────────────
            _buildTextFieldCard(
              label: '名前',
              controller: _nameController,
              hintText: '例: 財務レポート作成',
            ),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────────────────────
            _buildTextFieldCard(
              label: '説明',
              controller: _descriptionController,
              hintText: '例: 月次財務レポートの作成を支援します',
            ),
            const SizedBox(height: 16),

            // ── Category ───────────────────────────────────────────────────
            _buildCategoryCard(),
            const SizedBox(height: 16),

            // ── System prompt addition ─────────────────────────────────────
            _buildSystemPromptCard(),
            const SizedBox(height: 16),

            // ── Tool selection ─────────────────────────────────────────────
            ToolConfigSection(
              enabledTools: _enabledTools,
              onChanged: (newTools) {
                setState(() => _enabledTools = newTools);
              },
            ),
            const SizedBox(height: 24),

            // ── Save button ────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isNewSkill ? '追加' : '保存',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section cards
  // ---------------------------------------------------------------------------

  Widget _buildEmojiCard() {
    return Card(
      child: InkWell(
        onTap: _selectEmoji,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'アイコン',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _selectedEmoji,
                  style: const TextStyle(fontSize: 64),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'タップして変更',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldCard({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(color: AppTheme.lightTextPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'カテゴリ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SkillCategory>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: SkillCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemPromptCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AIへの追加指示',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'このスキルが有効な時に追加されるシステムプロンプト',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _systemPromptController,
              decoration: InputDecoration(
                hintText: '例: 財務データを分析する際は必ず根拠となる数値を明示してください',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(color: AppTheme.lightTextPrimary),
              maxLines: 6,
            ),
          ],
        ),
      ),
    );
  }
}
