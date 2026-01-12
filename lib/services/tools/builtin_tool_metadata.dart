import 'package:flutter/material.dart';
import 'tool_metadata.dart';

/// ビルトインツールのメタデータ定義
/// 
/// ツールの表示情報（日本語名、説明、アイコン）を一元管理。
/// tools_tab.dart の _getToolInfo() を置き換える。
class BuiltinToolMetadata {
  const BuiltinToolMetadata._();
  
  /// すべてのビルトインツールメタデータを取得
  static Map<String, ToolMetadata> get all => {
    'get_current_time': const ToolMetadata(
      name: 'get_current_time',
      displayName: '現在時刻',
      displayDescription: '現在の日時を取得します',
      description: 'Get the current date and time. Use this when the user asks about the current time or date.',
      icon: Icons.access_time,
      category: ToolCategory.system,
    ),
    'memory_save': const ToolMetadata(
      name: 'memory_save',
      displayName: 'メモリ保存',
      displayDescription: '重要な情報を記憶します',
      description: 'Save important information to memory for later recall.',
      icon: Icons.save,
      category: ToolCategory.memory,
    ),
    'memory_recall': const ToolMetadata(
      name: 'memory_recall',
      displayName: 'メモリ検索',
      displayDescription: '記憶した情報を検索します',
      description: 'Search and recall previously saved information from memory.',
      icon: Icons.search,
      category: ToolCategory.memory,
    ),
    'memory_delete': const ToolMetadata(
      name: 'memory_delete',
      displayName: 'メモリ削除',
      displayDescription: '記憶した情報を削除します',
      description: 'Delete specific information from memory.',
      icon: Icons.delete,
      category: ToolCategory.memory,
    ),
    'calculator': const ToolMetadata(
      name: 'calculator',
      displayName: '計算機',
      displayDescription: '数式を計算します',
      description: 'Evaluate mathematical expressions and perform calculations.',
      icon: Icons.calculate,
      category: ToolCategory.calculation,
    ),
    'notepad_list_tabs': const ToolMetadata(
      name: 'notepad_list_tabs',
      displayName: 'ノートパッド一覧',
      displayDescription: 'ノートパッドのタブ一覧を取得します',
      description: 'List all open notepad tabs.',
      icon: Icons.list,
      category: ToolCategory.notepad,
    ),
    'notepad_get_metadata': const ToolMetadata(
      name: 'notepad_get_metadata',
      displayName: 'ノートパッド情報',
      displayDescription: 'ノートパッドの詳細情報を取得します',
      description: 'Get metadata and details about a specific notepad tab.',
      icon: Icons.info,
      category: ToolCategory.notepad,
    ),
    'notepad_get_content': const ToolMetadata(
      name: 'notepad_get_content',
      displayName: 'ノートパッド読取',
      displayDescription: 'ノートパッドの内容を読み取ります',
      description: 'Read the content of a specific notepad tab.',
      icon: Icons.article,
      category: ToolCategory.notepad,
    ),
    'notepad_close_tab': const ToolMetadata(
      name: 'notepad_close_tab',
      displayName: 'ノートパッド閉じる',
      displayDescription: 'ノートパッドのタブを閉じます',
      description: 'Close a specific notepad tab.',
      icon: Icons.close,
      category: ToolCategory.notepad,
    ),
    'document_overwrite': const ToolMetadata(
      name: 'document_overwrite',
      displayName: 'ドキュメント作成',
      displayDescription: '新しいドキュメントを作成または上書きします',
      description: 'Create a new document or overwrite an existing one.',
      icon: Icons.edit_document,
      category: ToolCategory.document,
    ),
    'document_patch': const ToolMetadata(
      name: 'document_patch',
      displayName: 'ドキュメント編集',
      displayDescription: 'ドキュメントの一部を編集します',
      description: 'Edit a specific part of a document.',
      icon: Icons.edit,
      category: ToolCategory.document,
    ),
    'document_read': const ToolMetadata(
      name: 'document_read',
      displayName: 'ドキュメント表示',
      displayDescription: 'ドキュメントの内容を表示します',
      description: 'Read and display the content of a document.',
      icon: Icons.visibility,
      category: ToolCategory.document,
    ),
  };
  
  /// ツール名からメタデータを取得
  static ToolMetadata? getMetadata(String name) => all[name];
  
  /// すべてのツール名を取得
  static List<String> get allNames => all.keys.toList();
  
  /// カテゴリでグループ化したツールを取得
  static Map<ToolCategory, List<ToolMetadata>> get byCategory {
    final result = <ToolCategory, List<ToolMetadata>>{};
    for (final metadata in all.values) {
      result.putIfAbsent(metadata.category, () => []).add(metadata);
    }
    return result;
  }
}
