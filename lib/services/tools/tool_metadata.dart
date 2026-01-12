import 'package:flutter/material.dart';

/// ツールのメタデータを表すクラス
/// 
/// ツールの表示情報（UI用）と定義情報（API用）を一元管理する。
/// 将来のMCP対応を視野に入れた拡張可能な設計。
class ToolMetadata {
  /// ツールの一意識別子（API送信用）
  final String name;
  
  /// ツールの日本語表示名（UI用）
  final String displayName;
  
  /// ツールの日本語説明（UI用）
  final String displayDescription;
  
  /// ツールの説明（AI用、英語）
  final String description;
  
  /// ツールのアイコン
  final IconData icon;
  
  /// ツールのカテゴリ
  final ToolCategory category;
  
  /// ツールのソース（ビルトイン/MCP/カスタム）
  final ToolSource source;
  
  /// MCPサーバーURL（MCPツールの場合）
  final String? mcpServerUrl;
  
  const ToolMetadata({
    required this.name,
    required this.displayName,
    required this.displayDescription,
    required this.description,
    required this.icon,
    required this.category,
    this.source = ToolSource.builtin,
    this.mcpServerUrl,
  });
}

/// ツールのカテゴリ
enum ToolCategory {
  /// システム系（時刻取得など）
  system,
  /// メモリ系（記憶保存・検索）
  memory,
  /// ドキュメント系（作成・編集）
  document,
  /// ノートパッド系（タブ管理）
  notepad,
  /// 計算系
  calculation,
  /// MCP連携
  mcp,
  /// カスタム
  custom,
}

/// カテゴリの日本語表示名を取得
extension ToolCategoryExtension on ToolCategory {
  String get displayName {
    switch (this) {
      case ToolCategory.system:
        return 'システム';
      case ToolCategory.memory:
        return 'メモリ';
      case ToolCategory.document:
        return 'ドキュメント';
      case ToolCategory.notepad:
        return 'ノートパッド';
      case ToolCategory.calculation:
        return '計算';
      case ToolCategory.mcp:
        return 'MCP連携';
      case ToolCategory.custom:
        return 'カスタム';
    }
  }
  
  IconData get icon {
    switch (this) {
      case ToolCategory.system:
        return Icons.settings;
      case ToolCategory.memory:
        return Icons.memory;
      case ToolCategory.document:
        return Icons.description;
      case ToolCategory.notepad:
        return Icons.note;
      case ToolCategory.calculation:
        return Icons.calculate;
      case ToolCategory.mcp:
        return Icons.cloud;
      case ToolCategory.custom:
        return Icons.extension;
    }
  }
}

/// ツールのソース
enum ToolSource {
  /// アプリ内蔵ツール
  builtin,
  /// MCPサーバーから動的取得
  mcp,
  /// ユーザー定義カスタムツール
  custom,
}

/// ソースの日本語表示名を取得
extension ToolSourceExtension on ToolSource {
  String get displayName {
    switch (this) {
      case ToolSource.builtin:
        return 'ビルトイン';
      case ToolSource.mcp:
        return 'MCP';
      case ToolSource.custom:
        return 'カスタム';
    }
  }
}
