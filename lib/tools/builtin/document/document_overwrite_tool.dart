import 'dart:convert';

import 'package:vagina/models/tabular_data.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';
import 'package:vagina/tools/builtin/shared/file_type_support.dart';

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
        description: 'Overwrite the working content of an active file by path.',
        activation: ToolActivation.forExtensions(kTextDocumentExtensions),
        parametersSchema: {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Absolute path of the active file to overwrite.',
            },
            'content': {
              'type': 'string',
              'description': 'The content of the document',
            },
          },
          'required': ['path', 'content'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String;
    final content = _coerceContentToString(args['content']);

    try {
      if (!isPathSupportedByActivation(path, definition.activation)) {
        return jsonEncode({
          'success': false,
          'error': 'Unsupported file type for document_overwrite: $path',
        });
      }

      final activeFile = await context.filesystemApi.getActiveFile(path);
      if (activeFile == null) {
        return jsonEncode({
          'success': false,
          'error': 'Active file not found: $path',
        });
      }

      if (isTabularPath(path)) {
        try {
          TabularData.validate(content, normalizedExtensionFromPath(path));
        } on TabularDataException catch (e) {
          return jsonEncode({
            'success': false,
            'errorCode': 'INVALID_TABULAR_CONTENT',
            'error': e.message,
          });
        }
      }

      await context.filesystemApi.updateActiveFile(path, content);
      return jsonEncode({
        'success': true,
        'path': path,
        'message': 'Document overwritten successfully',
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to save document: $e',
      });
    }
  }
}
