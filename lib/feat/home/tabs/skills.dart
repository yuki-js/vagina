import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/skills/screens/skill_editor.dart';
import 'package:vagina/feat/skills/state/skill_providers.dart';
import 'package:vagina/models/skill.dart';

/// スキル管理タブ
///
/// スキル一覧の表示・検索を担当する。
/// スキルをタップすると [SkillEditorScreen] が開き、編集できる。
class SkillsTab extends ConsumerStatefulWidget {
  const SkillsTab({super.key});

  @override
  ConsumerState<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<SkillsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsProvider);

    return skillsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('エラー: $error'),
      ),
      data: (skills) {
        if (skills.isEmpty) {
          return _buildEmptyState();
        }

        final filteredSkills = _searchQuery.isEmpty
            ? skills
            : skills.where((skill) {
                final query = _searchQuery.toLowerCase();
                return skill.name.toLowerCase().contains(query) ||
                    skill.description.toLowerCase().contains(query);
              }).toList();

        return Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: filteredSkills.isEmpty
                  ? _buildNoResultsState()
                  : _buildSkillList(filteredSkills),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'スキルを検索...',
          hintStyle: TextStyle(
            color: AppTheme.lightTextSecondary,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.lightTextSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppTheme.lightTextSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSkillList(List<Skill> skills) {
    return ListView.builder(
      itemCount: skills.length,
      itemBuilder: (context, index) {
        return _buildSkillListTile(skills[index]);
      },
    );
  }

  Widget _buildSkillListTile(Skill skill) {
    final emoji = skill.iconEmoji ?? '🔧';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
        color: Colors.white,
      ),
      child: ListTile(
        enableFeedback: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _categoryColor(skill.category).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          skill.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (skill.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                skill.description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            _buildCategoryBadge(skill.category),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppTheme.lightTextSecondary,
        ),
        onTap: () => _openSkillEditor(context, skill: skill),
      ),
    );
  }

  Widget _buildCategoryBadge(SkillCategory category) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 80,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'スキルがありません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '右上の + ボタンで追加できます',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '検索結果がありません',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSkillEditor(BuildContext context, {Skill? skill}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SkillEditorScreen(skill: skill),
      ),
    );
  }

  /// カテゴリに対応するブランドカラーを返す
  Color _categoryColor(SkillCategory category) {
    switch (category) {
      case SkillCategory.finance:
        return const Color(0xFF4CAF50); // Green
      case SkillCategory.document:
        return const Color(0xFF2196F3); // Blue
      case SkillCategory.communication:
        return const Color(0xFFE91E63); // Pink
      case SkillCategory.productivity:
        return const Color(0xFFFF9800); // Orange
      case SkillCategory.research:
        return const Color(0xFF9C27B0); // Purple
      case SkillCategory.custom:
        return AppTheme.primaryColor;
    }
  }
}
