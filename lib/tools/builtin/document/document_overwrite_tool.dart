import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class DocumentOverwriteTool implements Tool {
  static const String toolKeyName = 'document_overwrite';

  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ドキュメント作成',
        displayDescription: '新しいドキュメントを作成または上書きします',
        categoryKey: 'document',
        iconKey: 'edit_document',
        sourceKey: 'builtin',
        description:
            'Create a new document or overwrite an existing one. If tabId is not provided, creates a new tab. If tabId is provided, replaces the content of that tab. Use this for creating and fully replacing documents.',
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
                  'MIME type of the content (e.g., "text/markdown", "text/plain", "text/html"). Defaults to "text/markdown".',
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
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final tabId = args['tabId'] as String?;
    final content = args['content'] as String;
    final mime = (args['mime'] as String?) ?? 'text/markdown';
    final title = args['title'] as String?;

    try {
      if (tabId != null) {
        // 既存タブを更新
        final result = await context.notepadApi.updateTab(
          tabId,
          content: content,
          title: title,
          mimeType: mime,
        );

        if (!result) {
          return jsonEncode({
            'success': false,
            'error':
                'Tab not found: $tabId. Please create a new document without specifying tabId.',
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
