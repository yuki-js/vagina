import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../repositories/repository_factory.dart';

/// Provider for tool enabled states (uses repository)
final toolEnabledProvider = FutureProvider.family<bool, String>((ref, toolName) async {
  return await RepositoryFactory.config.isToolEnabled(toolName);
});

/// Tools tab - shows available tools with enable/disable toggle via long press
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

  void _selectAll(List<Map<String, dynamic>> tools) {
    setState(() {
      _selectedTools.clear();
      _selectedTools.addAll(tools.map((t) => t['name'] as String));
    });
  }

  void _invertSelection(List<Map<String, dynamic>> tools) {
    setState(() {
      final allNames = tools.map((t) => t['name'] as String).toSet();
      final newSelection = allNames.difference(_selectedTools);
      _selectedTools.clear();
      _selectedTools.addAll(newSelection);
    });
  }

  Future<void> _enableSelected() async {
    if (_selectedTools.isEmpty) return;

    final configRepo = RepositoryFactory.config;
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

    final configRepo = RepositoryFactory.config;
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
    final tools = toolService.toolDefinitions;

    return Column(
      children: [
        if (_isSelectionMode)
          Container(
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
                  onPressed: () => _selectAll(tools),
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('全選択'),
                ),
                TextButton.icon(
                  onPressed: () => _invertSelection(tools),
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
          ),
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
              // Tools list
              ...tools.map((tool) => _buildToolItem(context, tool)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolItem(BuildContext context, Map<String, dynamic> tool) {
    final name = tool['name'] as String;
    final isSelected = _selectedTools.contains(name);
    
    // Map tool names to friendly Japanese names and icons
    final toolInfo = _getToolInfo(name);
    final enabledAsync = ref.watch(toolEnabledProvider(name));

    return enabledAsync.when(
      data: (isEnabled) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(name);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedTools.add(name);
              });
            }
          },
          child: ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(name),
                  )
                : Icon(
                    toolInfo.icon,
                    color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                  ),
            title: Text(
              toolInfo.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isEnabled ? AppTheme.lightTextPrimary : Colors.grey,
              ),
            ),
            subtitle: Text(
              toolInfo.displayDescription,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled ? AppTheme.lightTextSecondary : Colors.grey,
              ),
            ),
            trailing: _isSelectionMode
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          leading: Icon(toolInfo.icon, color: Colors.grey),
          title: Text(toolInfo.displayName),
          subtitle: Text(toolInfo.displayDescription),
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

  _ToolInfo _getToolInfo(String toolName) {
    switch (toolName) {
      case 'get_current_time':
        return const _ToolInfo(
          icon: Icons.access_time,
          displayName: '現在時刻',
          displayDescription: '現在の日時を取得',
        );
      case 'memory_save':
        return const _ToolInfo(
          icon: Icons.save,
          displayName: 'メモリ保存',
          displayDescription: '重要な情報を記憶',
        );
      case 'memory_recall':
        return const _ToolInfo(
          icon: Icons.search,
          displayName: 'メモリ検索',
          displayDescription: '記憶した情報を検索',
        );
      case 'memory_delete':
        return const _ToolInfo(
          icon: Icons.delete,
          displayName: 'メモリ削除',
          displayDescription: '記憶した情報を削除',
        );
      case 'calculator':
        return const _ToolInfo(
          icon: Icons.calculate,
          displayName: '計算機',
          displayDescription: '数式を計算',
        );
      case 'notepad_list_tabs':
        return const _ToolInfo(
          icon: Icons.list,
          displayName: 'ノートパッド一覧',
          displayDescription: 'ノートパッドのタブ一覧を取得',
        );
      case 'notepad_get_metadata':
        return const _ToolInfo(
          icon: Icons.info,
          displayName: 'ノートパッド情報',
          displayDescription: 'ノートパッドの詳細情報を取得',
        );
      case 'notepad_get_content':
        return const _ToolInfo(
          icon: Icons.article,
          displayName: 'ノートパッド読取',
          displayDescription: 'ノートパッドの内容を読み取り',
        );
      case 'notepad_close_tab':
        return const _ToolInfo(
          icon: Icons.close,
          displayName: 'ノートパッド閉じる',
          displayDescription: 'ノートパッドのタブを閉じる',
        );
      case 'document_overwrite':
        return const _ToolInfo(
          icon: Icons.edit_document,
          displayName: 'ドキュメント作成',
          displayDescription: '新しいドキュメントを作成または上書き',
        );
      case 'document_patch':
        return const _ToolInfo(
          icon: Icons.edit,
          displayName: 'ドキュメント編集',
          displayDescription: 'ドキュメントの一部を編集',
        );
      case 'document_read':
        return const _ToolInfo(
          icon: Icons.visibility,
          displayName: 'ドキュメント表示',
          displayDescription: 'ドキュメントの内容を表示',
        );
      default:
        return _ToolInfo(
          icon: Icons.extension,
          displayName: toolName,
          displayDescription: 'ツール',
        );
    }
  }
}

class _ToolInfo {
  final IconData icon;
  final String displayName;
  final String displayDescription;

  const _ToolInfo({
    required this.icon,
    required this.displayName,
    required this.displayDescription,
  });
}
