import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';

/// Provider for tool enabled states
final toolEnabledProvider = FutureProvider.family<bool, String>((ref, toolName) async {
  final storage = ref.watch(storageServiceProvider);
  return await storage.isToolEnabled(toolName);
});

/// Tools tab - shows available tools with enable/disable toggle via long press
class ToolsTab extends ConsumerWidget {
  const ToolsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolService = ref.watch(toolServiceProvider);
    final tools = toolService.toolDefinitions;

    return ListView(
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
          'ツールを長押しして有効・無効を切り替え',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Tools list
        ...tools.map((tool) => _buildToolItem(context, ref, tool)),
      ],
    );
  }

  Widget _buildToolItem(BuildContext context, WidgetRef ref, Map<String, dynamic> tool) {
    final name = tool['name'] as String;
    
    // Map tool names to friendly Japanese names and icons
    final toolInfo = _getToolInfo(name);
    final enabledAsync = ref.watch(toolEnabledProvider(name));

    return enabledAsync.when(
      data: (isEnabled) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onLongPress: () async {
            // Toggle tool on long press
            final storage = ref.read(storageServiceProvider);
            await storage.toggleTool(name);
            ref.invalidate(toolEnabledProvider(name));
            
            // Show snackbar
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEnabled ? '${toolInfo.displayName}を無効にしました' : '${toolInfo.displayName}を有効にしました',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: ListTile(
            leading: Icon(
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
            trailing: Container(
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
