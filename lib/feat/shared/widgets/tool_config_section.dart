import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/feat/home/tools/tool_icon_mapper.dart';
import 'package:vagina/services/tool_metadata.dart';

/// ツール設定セクション - AgentFormScreenとSpeedDialConfigScreenで共通利用
///
/// カテゴリ別折りたたみ表示とチェックボックスでツールの有効/無効を設定する。
/// 設計ドキュメントのセクション7.3-7.5に基づく。
class ToolConfigSection extends ConsumerStatefulWidget {
  /// 現在のツール設定（キー: ツール名, 値: 有効/無効）
  /// 空Mapまたはキー不在の場合は `true`（有効）として扱う
  final Map<String, bool> enabledTools;

  /// ツール設定が変更された時のコールバック
  /// full Map（全ツールキーを含む）を渡す
  final ValueChanged<Map<String, bool>> onChanged;

  const ToolConfigSection({
    super.key,
    required this.enabledTools,
    required this.onChanged,
  });

  @override
  ConsumerState<ToolConfigSection> createState() => _ToolConfigSectionState();
}

class _ToolConfigSectionState extends ConsumerState<ToolConfigSection> {
  /// カテゴリの展開状態を管理
  final Map<ToolCategory, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // デフォルトでシステムカテゴリのみ展開
    _expandedCategories[ToolCategory.system] = true;
  }

  /// 指定されたツールの有効/無効状態を取得
  /// キー不在の場合は `true`（有効）を返す
  bool _isToolEnabled(String toolKey) {
    return widget.enabledTools[toolKey] ?? true;
  }

  /// 単一ツールの状態を変更
  void _toggleTool(String toolKey) {
    final newEnabledTools = Map<String, bool>.from(widget.enabledTools);
    newEnabledTools[toolKey] = !_isToolEnabled(toolKey);
    widget.onChanged(newEnabledTools);
  }

  /// すべてのツールを有効化
  void _enableAll(List<ToolMetadata> allTools) {
    final newEnabledTools = <String, bool>{};
    for (final tool in allTools) {
      newEnabledTools[tool.name] = true;
    }
    widget.onChanged(newEnabledTools);
  }

  /// すべてのツールを無効化
  void _disableAll(List<ToolMetadata> allTools) {
    final newEnabledTools = <String, bool>{};
    for (final tool in allTools) {
      newEnabledTools[tool.name] = false;
    }
    widget.onChanged(newEnabledTools);
  }

  /// 指定されたカテゴリのすべてのツールを有効化
  void _enableCategory(List<ToolMetadata> categoryTools) {
    final newEnabledTools = Map<String, bool>.from(widget.enabledTools);
    for (final tool in categoryTools) {
      newEnabledTools[tool.name] = true;
    }
    widget.onChanged(newEnabledTools);
  }

  /// 指定されたカテゴリのすべてのツールを無効化
  void _disableCategory(List<ToolMetadata> categoryTools) {
    final newEnabledTools = Map<String, bool>.from(widget.enabledTools);
    for (final tool in categoryTools) {
      newEnabledTools[tool.name] = false;
    }
    widget.onChanged(newEnabledTools);
  }

  /// カテゴリ内のツールがすべて有効かどうか
  bool _isAllCategoryEnabled(List<ToolMetadata> categoryTools) {
    return categoryTools.every((tool) => _isToolEnabled(tool.name));
  }

  @override
  Widget build(BuildContext context) {
    final toolService = ref.watch(toolServiceProvider);
    final toolList = toolService.registeredToolMeta;

    // カテゴリ別にグルーピング
    final toolsByCategory =
        toolList.fold<Map<ToolCategory, List<ToolMetadata>>>({}, (map, tool) {
      final category = tool.category;
      if (!map.containsKey(category)) {
        map[category] = [];
      }
      map[category]!.add(tool);
      return map;
    });

    // カテゴリを定義順にソート
    final sortedCategories = toolsByCategory.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'ツール設定',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTextPrimary,
            ),
          ),
        ),

        // 全体操作ボタン
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _enableAll(toolList),
                icon: const Icon(Icons.check_box, size: 18),
                label: const Text('すべて選択'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _disableAll(toolList),
                icon: const Icon(Icons.check_box_outline_blank, size: 18),
                label: const Text('すべて解除'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),

        // カテゴリ別ツールリスト
        ...sortedCategories.map((category) {
          final categoryTools = toolsByCategory[category]!;
          final isExpanded = _expandedCategories[category] ?? false;
          final allEnabled = _isAllCategoryEnabled(categoryTools);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ExpansionTile(
              key: PageStorageKey<String>('category_${category.name}'),
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedCategories[category] = expanded;
                });
              },
              leading: Icon(
                ToolIconMapper.iconForCategory(category),
                color: AppTheme.primaryColor,
                size: 24,
              ),
              title: Row(
                children: [
                  Text(
                    category.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${categoryTools.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // カテゴリ全選択/解除ボタン
                  IconButton(
                    icon: Icon(
                      allEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20,
                    ),
                    color: allEnabled
                        ? AppTheme.primaryColor
                        : AppTheme.lightTextSecondary,
                    tooltip: allEnabled ? '全選択解除' : '全選択',
                    onPressed: () {
                      if (allEnabled) {
                        _disableCategory(categoryTools);
                      } else {
                        _enableCategory(categoryTools);
                      }
                    },
                  ),
                  // 展開/折りたたみアイコンはExpansionTileが自動で表示
                ],
              ),
              children: categoryTools.map((tool) {
                final isEnabled = _isToolEnabled(tool.name);
                return CheckboxListTile(
                  value: isEnabled,
                  onChanged: (_) => _toggleTool(tool.name),
                  title: Text(
                    tool.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? AppTheme.lightTextPrimary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  subtitle: Text(
                    tool.displayDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled
                          ? AppTheme.lightTextSecondary
                          : Colors.grey,
                    ),
                  ),
                  secondary: Icon(
                    ToolIconMapper.iconForMetadata(tool),
                    color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                );
              }).toList(),
            ),
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }
}
