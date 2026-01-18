import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/feat/home/tools/tool_icon_mapper.dart';
import 'package:vagina/services/tool_metadata.dart';

/// ツール有効状態のプロバイダー（リポジトリ使用）
final toolEnabledProvider =
    FutureProvider.family<bool, String>((ref, toolName) async {
  final config = ref.watch(configRepositoryProvider);
  return await config.isToolEnabled(toolName);
});

/// ツールタブ - 利用可能なツールを表示し、長押しで有効/無効を切り替え
class ToolsTab extends ConsumerStatefulWidget {
  const ToolsTab({super.key});

  @override
  ConsumerState<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends ConsumerState<ToolsTab> {
  bool _isSelectionMode = false;
  final Set<String> _selectedTools = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTools.clear();
      }
    });
  }

  void _toggleSelection(String toolName) {
    setState(() {
      if (_selectedTools.contains(toolName)) {
        _selectedTools.remove(toolName);
      } else {
        _selectedTools.add(toolName);
      }
    });
  }

  void _selectAll(List<ToolMetadata> tools) {
    setState(() {
      _selectedTools.clear();
      _selectedTools.addAll(tools.map((t) => t.name));
    });
  }

  void _invertSelection(List<ToolMetadata> tools) {
    setState(() {
      final allNames = tools.map((t) => t.name).toSet();
      final newSelection = allNames.difference(_selectedTools);
      _selectedTools.clear();
      _selectedTools.addAll(newSelection);
    });
  }

  Future<void> _enableSelected() async {
    if (_selectedTools.isEmpty) return;

    final configRepo = ref.read(configRepositoryProvider);
    for (final toolName in _selectedTools) {
      final isEnabled = await configRepo.isToolEnabled(toolName);
      if (!isEnabled) {
        await configRepo.toggleTool(toolName);
        ref.invalidate(toolEnabledProvider(toolName));
      }
    }

    setState(() {
      _selectedTools.clear();
      _isSelectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択したツールを有効にしました')),
      );
    }
  }

  Future<void> _disableSelected() async {
    if (_selectedTools.isEmpty) return;

    final configRepo = ref.read(configRepositoryProvider);
    for (final toolName in _selectedTools) {
      final isEnabled = await configRepo.isToolEnabled(toolName);
      if (isEnabled) {
        await configRepo.toggleTool(toolName);
        ref.invalidate(toolEnabledProvider(toolName));
      }
    }

    setState(() {
      _selectedTools.clear();
      _isSelectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択したツールを無効にしました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final toolService = ref.watch(toolServiceProvider);
    final toolsByCategory = toolService.toolsByCategory;

    return Column(
      children: [
        // 選択モードのヘッダー
        if (_isSelectionMode) _buildSelectionHeader(toolsByCategory),

        // ツールリスト
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'ツール',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ツールを長押しして選択モードを開始',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // カテゴリ別にツールを表示
              ...toolsByCategory.entries.map(
                  (entry) => _buildCategorySection(entry.key, entry.value)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(
      Map<ToolCategory, List<ToolMetadata>> toolsByCategory) {
    final allTools = toolsByCategory.values.expand((list) => list).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(
            '${_selectedTools.length}件選択中',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _selectAll(allTools),
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('全選択'),
          ),
          TextButton.icon(
            onPressed: () => _invertSelection(allTools),
            icon: const Icon(Icons.swap_vert, size: 18),
            label: const Text('反転'),
          ),
          IconButton(
            onPressed: _selectedTools.isNotEmpty ? _enableSelected : null,
            icon: const Icon(Icons.check_circle),
            color: AppTheme.successColor,
            tooltip: '有効化',
          ),
          IconButton(
            onPressed: _selectedTools.isNotEmpty ? _disableSelected : null,
            icon: const Icon(Icons.cancel),
            color: AppTheme.errorColor,
            tooltip: '無効化',
          ),
          IconButton(
            onPressed: _toggleSelectionMode,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
      ToolCategory category, List<ToolMetadata> tools) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // カテゴリヘッダー
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                ToolIconMapper.iconForCategory(category),
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tools.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ツールアイテム
        ...tools.map((metadata) => _buildToolItem(context, metadata)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildToolItem(BuildContext context, ToolMetadata metadata) {
    final isSelected = _selectedTools.contains(metadata.name);
    final enabledAsync = ref.watch(toolEnabledProvider(metadata.name));

    return enabledAsync.when(
      data: (isEnabled) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(metadata.name);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedTools.add(metadata.name);
              });
            }
          },
          child: ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(metadata.name),
                  )
                : Icon(
                    ToolIconMapper.iconForMetadata(metadata),
                    color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                  ),
            title: Text(
              metadata.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isEnabled ? AppTheme.lightTextPrimary : Colors.grey,
              ),
            ),
            subtitle: Text(
              metadata.displayDescription,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled ? AppTheme.lightTextSecondary : Colors.grey,
              ),
            ),
            trailing: _isSelectionMode
                ? null
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isEnabled ? '有効' : '無効',
                      style: TextStyle(
                        fontSize: 12,
                        color: isEnabled ? AppTheme.successColor : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
      ),
      loading: () => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(
            ToolIconMapper.iconForMetadata(metadata),
            color: Colors.grey,
          ),
          title: Text(metadata.displayName),
          subtitle: Text(metadata.displayDescription),
          trailing: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox(),
    );
  }
}
