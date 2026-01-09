import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';

/// Tools tab - shows available tools (currently read-only, all tools always enabled)
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
          '利用可能なツール一覧（すべて有効）',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Tools list
        ...tools.map((tool) => _buildToolItem(tool)),
      ],
    );
  }

  Widget _buildToolItem(Map<String, dynamic> tool) {
    final name = tool['name'] as String;
    
    // Map tool names to friendly Japanese names and icons
    final toolInfo = _getToolInfo(name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(toolInfo.icon, color: AppTheme.primaryColor),
        title: Text(
          toolInfo.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          toolInfo.displayDescription,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '有効',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.successColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
