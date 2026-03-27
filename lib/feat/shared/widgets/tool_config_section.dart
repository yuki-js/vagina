import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/home/tools/tool_icon_mapper.dart';
import 'package:vagina/services/tool_registry.dart';
import 'package:vagina/models/tool_metadata.dart';

/// ツール設定セクション - AgentFormScreenとSpeedDialConfigScreenで共通利用
///
/// カテゴリタブ + チップベースのUIでツールの有効/無効を設定する。
/// 設計ドキュメントのセクション7.3-7.5に基づく。
class ToolConfigSection extends StatefulWidget {
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
  State<ToolConfigSection> createState() => _ToolConfigSectionState();
}

class _ToolConfigSectionState extends State<ToolConfigSection> {
  /// 選択中のタブインデックス
  int _selectedTabIndex = 0;

  /// タブバーのスクロールコントローラー
  final ScrollController _tabScrollController = ScrollController();

  /// 各タブのGlobalKey
  final Map<int, GlobalKey> _tabKeys = {};

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
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

  /// 選択したタブを画面中央にスクロール
  void _scrollTabToCenter(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _tabKeys[index];
      if (key?.currentContext == null) return;

      final RenderBox? renderBox =
          key!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final tabPosition = renderBox.localToGlobal(Offset.zero);
      final tabWidth = renderBox.size.width;
      final screenWidth = MediaQuery.of(context).size.width;

      // タブの中心を画面の中心に持ってくる
      final targetScrollOffset = _tabScrollController.offset +
          tabPosition.dx -
          (screenWidth / 2) +
          (tabWidth / 2);

      _tabScrollController.animateTo(
        targetScrollOffset.clamp(
          _tabScrollController.position.minScrollExtent,
          _tabScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final toolRegistry = ToolRegistry();
    final toolList = toolRegistry.registeredToolMeta;

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

    // タブインデックスが範囲外の場合は修正
    if (_selectedTabIndex >= sortedCategories.length) {
      _selectedTabIndex = 0;
    }

    final currentCategory = sortedCategories[_selectedTabIndex];
    final currentTools = toolsByCategory[currentCategory]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダーは実装してはいけない。外側の画面で共通のセクションヘッダーを実装すること。

        // 全体操作ボタン
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _enableAll(toolList),
                icon: const Icon(Icons.check_box, size: 16),
                label: const Text('すべて選択'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () => _disableAll(toolList),
                icon: const Icon(Icons.check_box_outline_blank, size: 16),
                label: const Text('すべて解除'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.lightTextSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),

        // カテゴリタブ
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _tabScrollController,
            child: Row(
              children: sortedCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final isSelected = _selectedTabIndex == index;
                
                // 各タブにキーを設定
                _tabKeys.putIfAbsent(index, () => GlobalKey());
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                    _scrollTabToCenter(index);
                  },
                  child: Container(
                    key: _tabKeys[index],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ToolIconMapper.iconForCategory(category),
                          size: 18,
                          color:
                              isSelected ? Colors.white : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // チップ表示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentTools.map((tool) {
              final isEnabled = _isToolEnabled(tool.name);
              return FilterChip(
                selected: isEnabled,
                showCheckmark: false,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ToolIconMapper.iconForMetadata(tool),
                      size: 16,
                      color: isEnabled ? Colors.white : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(tool.displayName),
                  ],
                ),
                onSelected: (_) => _toggleTool(tool.name),
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: isEnabled ? Colors.white : AppTheme.lightTextPrimary,
                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color:
                      isEnabled ? AppTheme.primaryColor : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
