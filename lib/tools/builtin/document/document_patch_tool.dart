import 'dart:convert';

import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

class _DocumentPatchFailure implements Exception {
  final Map<String, dynamic> details;

  _DocumentPatchFailure(this.details);

  @override
  String toString() => jsonEncode(details);
}

Map<String, dynamic> _coercePatchToObject(dynamic rawPatch) {
  if (rawPatch is Map<String, dynamic>) {
    return rawPatch;
  }
  if (rawPatch is Map) {
    return Map<String, dynamic>.from(rawPatch);
  }

  if (rawPatch is String) {
    final trimmed = rawPatch.trim();
    if (trimmed.isEmpty) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_PATCH_SCHEMA',
        'error': 'patch must be a non-empty object',
      });
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_PATCH_SCHEMA',
        'error': 'patch must be a JSON object',
      });
    } catch (_) {
      // Backward-incompatible change: unified diff is no longer supported.
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'UNSUPPORTED_PATCH_FORMAT',
        'error':
            'document_patch no longer accepts unified diff strings. Provide a structured patch object instead.',
      });
    }
  }

  throw _DocumentPatchFailure({
    'success': false,
    'errorCode': 'INVALID_PATCH_SCHEMA',
    'error': 'patch must be an object',
  });
}

int _findNthOccurrence(String content, String target, int occurrence) {
  if (occurrence < 1) return -1;

  var fromIndex = 0;
  var idx = -1;

  for (var i = 0; i < occurrence; i++) {
    idx = content.indexOf(target, fromIndex);
    if (idx < 0) return -1;
    fromIndex = idx + target.length;
  }

  return idx;
}

String _applyOperation(
  String content,
  Map<String, dynamic> op,
  int index,
) {
  final opType = op['op'];
  final target = op['target'];

  if (opType is! String) {
    throw _DocumentPatchFailure({
      'success': false,
      'errorCode': 'INVALID_PATCH_SCHEMA',
      'error': 'operations[$index].op must be a string',
      'failedOperationIndex': index,
    });
  }
  if (target is! String || target.isEmpty) {
    throw _DocumentPatchFailure({
      'success': false,
      'errorCode': 'INVALID_PATCH_SCHEMA',
      'error': 'operations[$index].target must be a non-empty string',
      'failedOperationIndex': index,
    });
  }

  final rawOccurrence = op['occurrence'];
  var occurrence = 1;
  if (rawOccurrence != null) {
    if (rawOccurrence is int) {
      occurrence = rawOccurrence;
    } else if (rawOccurrence is num && rawOccurrence % 1 == 0) {
      occurrence = rawOccurrence.toInt();
    } else {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_PATCH_SCHEMA',
        'error': 'operations[$index].occurrence must be an integer >= 1',
        'failedOperationIndex': index,
      });
    }
    if (occurrence < 1) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_PATCH_SCHEMA',
        'error': 'operations[$index].occurrence must be an integer >= 1',
        'failedOperationIndex': index,
      });
    }
  }

  final start = _findNthOccurrence(content, target, occurrence);
  if (start < 0) {
    throw _DocumentPatchFailure({
      'success': false,
      'errorCode': 'TARGET_NOT_FOUND',
      'error':
          'Target text not found for operations[$index] (occurrence=$occurrence). Ensure target is copied exactly from the current document.',
      'failedOperationIndex': index,
      'op': opType,
      'occurrence': occurrence,
    });
  }

  switch (opType) {
    case 'replace':
      final newText = op['newText'];
      if (newText is! String) {
        throw _DocumentPatchFailure({
          'success': false,
          'errorCode': 'INVALID_PATCH_SCHEMA',
          'error': 'operations[$index].newText must be a string for op=replace',
          'failedOperationIndex': index,
        });
      }
      return content.replaceRange(start, start + target.length, newText);

    case 'insert_before':
      final newText = op['newText'];
      if (newText is! String) {
        throw _DocumentPatchFailure({
          'success': false,
          'errorCode': 'INVALID_PATCH_SCHEMA',
          'error':
              'operations[$index].newText must be a string for op=insert_before',
          'failedOperationIndex': index,
        });
      }
      return content.replaceRange(start, start, newText);

    case 'insert_after':
      final newText = op['newText'];
      if (newText is! String) {
        throw _DocumentPatchFailure({
          'success': false,
          'errorCode': 'INVALID_PATCH_SCHEMA',
          'error':
              'operations[$index].newText must be a string for op=insert_after',
          'failedOperationIndex': index,
        });
      }
      return content.replaceRange(start + target.length, start + target.length,
          newText);

    case 'delete':
      return content.replaceRange(start, start + target.length, '');

    default:
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_PATCH_SCHEMA',
        'error':
            'operations[$index].op must be one of: replace, insert_before, insert_after, delete',
        'failedOperationIndex': index,
      });
  }
}

bool _isTabularMimeType(String? mimeType) {
  if (mimeType == null) return false;
  return mimeType == 'text/csv' ||
      mimeType == 'application/vagina-2d+json' ||
      mimeType == 'application/vagina-2d+jsonl';
}

class DocumentPatchTool extends Tool {
  static const String toolKeyName = 'document_patch';

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ドキュメント編集',
        displayDescription: 'ドキュメントの一部を編集します',
        categoryKey: 'document',
        iconKey: 'edit',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description:
            'Edit an existing text document using structured patch operations (NOT unified diff). '
            'Each operation finds an exact target snippet copied from the current document and then replaces/inserts/deletes it. '
            'This is intended for small localized edits on text documents (text/markdown, text/plain, text/html). '
            'Do NOT use this for tabular/spreadsheet documents (text/csv, application/vagina-2d+json, application/vagina-2d+jsonl). '
            'For spreadsheet edits, use spreadsheet_add_rows, spreadsheet_update_rows, or spreadsheet_delete_rows instead.\n\n'
            'Patch format example:\n'
            '{\n'
            '  "operations": [\n'
            '    {"op": "replace", "target": "old text", "newText": "new text"},\n'
            '    {"op": "insert_after", "target": "Heading\\n", "newText": "\\nNew paragraph\\n"}\n'
            '  ]\n'
            '}',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'ID of the tab containing the document to patch',
            },
            'patch': {
              'type': 'object',
              'description':
                  'Structured patch object. Contains an ordered list of operations to apply.',
              'properties': {
                'operations': {
                  'type': 'array',
                  'description': 'Patch operations to apply in order',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'op': {
                        'type': 'string',
                        'enum': [
                          'replace',
                          'insert_before',
                          'insert_after',
                          'delete',
                        ],
                        'description': 'Operation type',
                      },
                      'target': {
                        'type': 'string',
                        'description':
                            'Exact text snippet copied from the current document. Can be multiline.',
                      },
                      'occurrence': {
                        'type': 'integer',
                        'minimum': 1,
                        'description':
                            'Which occurrence of target to edit (1-based). Defaults to 1 if omitted.',
                      },
                      'newText': {
                        'type': 'string',
                        'description':
                            'New text for replace/insert operations. Omit or empty for delete.',
                      },
                    },
                    'required': ['op', 'target'],
                  },
                },
              },
              'required': ['operations'],
            },
          },
          'required': ['tabId', 'patch'],
        },
      );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final tabId = args['tabId'] as String;
    final rawPatch = args['patch'];

    final tab = await context.notepadApi.getTab(tabId);
    if (tab == null) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'TAB_NOT_FOUND',
        'error': 'Tab not found: $tabId',
      });
    }

    final mimeType = tab['mimeType'] as String?;
    if (_isTabularMimeType(mimeType)) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'UNSUPPORTED_MIME_TYPE',
        'error':
            'Tab "$tabId" is a tabular type (mimeType: $mimeType). document_patch only supports text documents.',
      });
    }

    final originalContent = tab['content'] as String?;
    if (originalContent == null) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_DOCUMENT',
        'error': 'Tab "$tabId" has no string content.',
      });
    }

    final patchObj = _coercePatchToObject(rawPatch);
    final operationsRaw = patchObj['operations'];
    if (operationsRaw is! List) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_PATCH_SCHEMA',
        'error': 'patch.operations must be an array',
      });
    }
    if (operationsRaw.isEmpty) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'INVALID_PATCH_SCHEMA',
        'error': 'patch.operations must not be empty',
      });
    }

    // Apply operations on a working copy. Persist only if ALL operations succeed.
    var working = originalContent;
    final operationResults = <Map<String, dynamic>>[];

    for (var i = 0; i < operationsRaw.length; i++) {
      final rawOp = operationsRaw[i];
      if (rawOp is! Map) {
        throw _DocumentPatchFailure({
          'success': false,
          'errorCode': 'INVALID_PATCH_SCHEMA',
          'error': 'operations[$i] must be an object',
          'failedOperationIndex': i,
        });
      }

      final op = Map<String, dynamic>.from(rawOp);

      try {
        working = _applyOperation(working, op, i);
        operationResults.add({
          'index': i,
          'op': op['op'],
          'success': true,
        });
      } on _DocumentPatchFailure catch (e) {
        // Include partial progress for debugging, but treat as tool error.
        final details = Map<String, dynamic>.from(e.details);
        details['operationResults'] = operationResults;
        throw _DocumentPatchFailure(details);
      }
    }

    final updateSuccess =
        await context.notepadApi.updateTab(tabId, content: working);

    if (!updateSuccess) {
      throw _DocumentPatchFailure({
        'success': false,
        'errorCode': 'UPDATE_FAILED',
        'error': 'Failed to update document after applying operations.',
        'tabId': tabId,
      });
    }

    return jsonEncode({
      'success': true,
      'tabId': tabId,
      'appliedOperations': operationsRaw.length,
      'message': 'All operations applied successfully',
      'operationResults': operationResults,
    });
  }
}
