import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// Coerce a content argument to a String.
///
/// AI models may send structured data (JSON array/object) instead of a string
/// when targeting tabular MIME types. In that case we JSON-encode it.
String _coerceContentToString(dynamic raw) {
  if (raw is String) return raw;
  return jsonEncode(raw);
}

class DocumentOverwriteTool extends Tool {
  static const String toolKeyName = 'document_overwrite';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ドキュメント作成',
        displayDescription: '新しいドキュメントを作成または上書きします',
        categoryKey: 'document',
        iconKey: 'edit_document',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Create a new document or overwrite an existing one. If tabId is not provided, creates a new tab. If tabId is provided, replaces the content of that tab. Use this for creating and fully replacing documents. '
            'Supports tabular MIME types: "text/csv", "application/vagina-2d+json" (JSON array of uniform objects), '
            '"application/vagina-2d+jsonl" (JSON Lines of uniform objects). For tabular types, content is validated on save. '
            'For incremental spreadsheet edits (add/update/delete rows), prefer the spreadsheet_* tools instead.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description':
                  'Optional: ID of an existing tab to overwrite. If not provided, creates a new tab.',
            },
            'content': {
              'type': 'string',
              'description': 'The content of the document',
            },
            'mime': {
              'type': 'string',
              'description':
                  'MIME type of the content (e.g., "text/markdown", "text/plain", "text/html", '
                      '"text/csv", "application/vagina-2d+json", "application/vagina-2d+jsonl"). '
                      'Defaults to "text/markdown".',
            },
            'title': {
              'type': 'string',
              'description':
                  'Optional title for the document. If not provided, will be auto-generated from content.',
            },
          },
          'required': ['content'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final tabId = args['tabId'] as String?;
    final content = _coerceContentToString(args['content']);
    final mime = (args['mime'] as String?) ?? 'text/markdown';
    final title = args['title'] as String?;

    try {
      if (tabId != null) {
        // 既存タブを更新
        // まず既存タブの情報を取得してMIMEタイプをチェック
        final existingTab = await context.notepadApi.getTab(tabId);

        if (existingTab == null) {
          return jsonEncode({
            'success': false,
            'error':
                'Tab not found: $tabId. Please create a new document without specifying tabId.',
          });
        }

        // MIMEタイプの変更を検証
        final existingMime = existingTab['mimeType'] as String?;
        if (existingMime != null && existingMime != mime) {
          return jsonEncode({
            'success': false,
            'error':
                'MIME type mismatch: Cannot change document type from "$existingMime" to "$mime". '
                    'To change the document type, please create a new document with a different tabId, '
                    'or use the same MIME type "$existingMime" for updates.',
          });
        }

        final result = await context.notepadApi.updateTab(
          tabId,
          content: content,
          title: title,
          mimeType: mime,
        );

        if (!result) {
          return jsonEncode({
            'success': false,
            'error': 'Failed to update tab: $tabId',
          });
        }

        return jsonEncode({
          'success': true,
          'tabId': tabId,
          'message': 'Document updated successfully',
        });
      } else {
        // 新規タブを作成
        final newTabId = await context.notepadApi.createTab(
          content: content,
          mimeType: mime,
          title: title,
        );

        return jsonEncode({
          'success': true,
          'tabId': newTabId,
          'message': 'Document created successfully',
        });
      }
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to save document: $e',
      });
    }
  }
}
