import 'package:flutter/material.dart';
import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';
import 'package:vagina/services/notepad_service.dart';

/// ドキュメント作成/上書きツール
class DocumentOverwriteTool extends BaseTool {
  final NotepadService _notepadService;
  
  DocumentOverwriteTool({required NotepadService notepadService}) 
      : _notepadService = notepadService;
  
  @override
  String get name => 'document_overwrite';
  
  @override
  String get description => 
      'Create a new document or overwrite an existing one. If tabId is not provided, creates a new tab. If tabId is provided, replaces the content of that tab. Use this for creating and fully replacing documents.';
  
  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'tabId': {
        'type': 'string',
        'description': 'Optional: ID of an existing tab to overwrite. If not provided, creates a new tab.',
      },
      'content': {
        'type': 'string',
        'description': 'The content of the document',
      },
      'mime': {
        'type': 'string',
        'description': 'MIME type of the content (e.g., "text/markdown", "text/plain", "text/html"). Defaults to "text/markdown".',
      },
      'title': {
        'type': 'string',
        'description': 'Optional title for the document. If not provided, will be auto-generated from content.',
      },
    },
    'required': ['content'],
  };
  
  @override
  ToolMetadata get metadata => const ToolMetadata(
    name: 'document_overwrite',
    displayName: 'ドキュメント作成',
    displayDescription: '新しいドキュメントを作成または上書きします',
    description: 'Create a new document or overwrite an existing one.',
    icon: Icons.edit_document,
    category: ToolCategory.document,
  );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final tabId = arguments['tabId'] as String?;
    final content = arguments['content'] as String;
    final mime = (arguments['mime'] as String?) ?? 'text/markdown';
    final title = arguments['title'] as String?;
    
    try {
      if (tabId != null) {
        // 既存タブを更新
        final success = _notepadService.updateTab(
          tabId, 
          content: content, 
          title: title,
          mimeType: mime,
        );
        
        if (!success) {
          return {
            'success': false,
            'error': 'Tab not found: $tabId. Please create a new document without specifying tabId.',
          };
        }
        
        return {
          'success': true,
          'tabId': tabId,
          'message': 'Document updated successfully',
        };
      } else {
        // 新規タブを作成
        final newTabId = _notepadService.createTab(
          content: content,
          mimeType: mime,
          title: title,
        );
        
        return {
          'success': true,
          'tabId': newTabId,
          'message': 'Document created successfully',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to save document: $e',
      };
    }
  }
}
