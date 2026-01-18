import 'dart:convert';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:vagina/services/tools_runtime/tool.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

/// unified diff形式のパッチをdiff_match_patchライブラリの形式に変換
///
/// diff_match_patchライブラリは2種類のパッチを処理できる：
/// 1. ライブラリ生成パッチ: URLエンコードされたコンテンツ (%0A, %E3など)
/// 2. AI生成パッチ: 非ASCIIにはエンコードが必要なプレーンテキスト
///
/// This function:
/// - If patch already has URL-encoding, returns as-is
/// - If patch has non-ASCII characters, encodes them and adds %0A line endings
/// - Otherwise, returns as-is (ASCII-only library patches)
String _encodePatchText(String patchText) {
  final lines = patchText.split('\n');
  final headerPattern =
      RegExp(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@');

  // Pattern to detect UTF-8 multi-byte characters in URL-encoded format
  // Matches patterns like %E3%81%82 (Japanese hiragana あ)
  // First byte: %C0-%DF (2-byte), %E0-%EF (3-byte), %F0-%F7 (4-byte)
  // Continuation bytes: %80-%BF
  final urlEncodedMultibytePattern =
      RegExp(r'%[EeDdCc][0-9A-Fa-f]%[89AaBb][0-9A-Fa-f]');

  // Pattern to detect non-ASCII characters (any character outside 0x00-0x7F range)
  final nonAsciiPattern = RegExp(r'[^\x00-\x7F]');

  // Check if patch content contains URL-encoded sequences or non-ASCII characters
  var hasUrlEncoding = false;
  var hasNonAscii = false;

  for (final line in lines) {
    if (line.isNotEmpty &&
        !headerPattern.hasMatch(line) &&
        (line.startsWith('+') || line.startsWith('-') || line.startsWith(' '))) {
      final content = line.substring(1);

      // Check for URL-encoded newline (%0A) or multi-byte characters
      if (content.contains('%0A') || urlEncodedMultibytePattern.hasMatch(content)) {
        hasUrlEncoding = true;
        break;
      }

      // Check for non-ASCII characters
      if (nonAsciiPattern.hasMatch(content)) {
        hasNonAscii = true;
      }
    }
  }

  // If already URL-encoded, return as-is
  if (hasUrlEncoding) {
    return patchText;
  }

  // If no non-ASCII characters, assume it's a library patch and return as-is
  if (!hasNonAscii) {
    return patchText;
  }

  // Has non-ASCII, needs encoding - this is an AI-generated patch
  // Find all patch sections
  final sections = <List<String>>[];
  List<String>? currentSection;

  for (final line in lines) {
    if (headerPattern.hasMatch(line)) {
      if (currentSection != null) {
        sections.add(currentSection);
      }
      currentSection = [line];
    } else if (currentSection != null) {
      currentSection.add(line);
    }
  }
  if (currentSection != null && currentSection.isNotEmpty) {
    sections.add(currentSection);
  }

  if (sections.isEmpty) {
    return patchText;
  }

  final encodedSections = <String>[];

  for (final section in sections) {
    final header = section[0];
    final processedLines = <String>[];
    processedLines.add(header);

    for (var i = 1; i < section.length; i++) {
      final line = section[i];

      if (line.isEmpty) continue;

      if (line.startsWith('+') || line.startsWith('-') || line.startsWith(' ')) {
        final prefix = line[0];
        final content = line.substring(1);

        // URL encode the content
        var encoded = Uri.encodeFull(content);
        encoded = encoded.replaceAll('%20', ' ');
        // Add newline at end - AI patches represent full lines
        encoded = '$encoded%0A';

        processedLines.add('$prefix$encoded');
      } else {
        processedLines.add(line);
      }
    }

    encodedSections.add(processedLines.join('\n'));
  }

  return encodedSections.join('\n');
}

class DocumentPatchTool implements Tool {
  static const String toolKeyName = 'document_patch';

  final AsyncOnce<void> _initOnce = AsyncOnce<void>();

  @override
  ToolDefinition get definition => const ToolDefinition(
        toolKey: toolKeyName,
        displayName: 'ドキュメント編集',
        displayDescription: 'ドキュメントの一部を編集します',
        categoryKey: 'document',
        iconKey: 'edit',
        sourceKey: 'builtin',
        description:
            'Apply a unified diff patch to an existing document. Use standard unified diff format (like git diff or diff -u). This is the preferred way to make small changes to existing documents.',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'tabId': {
              'type': 'string',
              'description': 'ID of the tab containing the document to patch',
            },
            'patch': {
              'type': 'string',
              'description':
                  'Unified diff format patch to apply. Lines starting with "-" are removed, lines starting with "+" are added. Context lines (no prefix) help locate the change.',
            },
          },
          'required': ['tabId', 'patch'],
        },
      );

  @override
  Future<void> init() => _initOnce.run(() async {});

  @override
  Future<String> execute(ToolArgs args, ToolContext context) async {
    final tabId = args['tabId'] as String;
    final patchText = args['patch'] as String;

    final tab = context.notepadService.getTab(tabId);
    if (tab == null) {
      return jsonEncode({
        'success': false,
        'error': 'Tab not found: $tabId',
      });
    }

    final originalContent = tab.content;

    // Convert plain diff format to URL-encoded format expected by the library
    final encodedPatch = _encodePatchText(patchText);

    // Parse the patch
    List<Patch> patches;
    try {
      patches = patchFromText(encodedPatch);
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error':
            'Invalid patch format: $e. Please use unified diff format.',
      });
    }

    if (patches.isEmpty) {
      return jsonEncode({
        'success': false,
        'error': 'No valid patches found in the provided diff.',
      });
    }

    // Apply the patch
    final result = patchApply(patches, originalContent);
    final patchedContent = result[0] as String;
    final patchResults = result[1] as List<bool>;

    // Check if all patches were applied successfully
    final successCount = patchResults.where((r) => r).length;
    final failCount = patchResults.where((r) => !r).length;

    if (failCount > 0 && successCount == 0) {
      return jsonEncode({
        'success': false,
        'error':
            'Failed to apply any patches. The document content may have changed since the diff was created.',
        'failedPatches': failCount,
      });
    }

    // Update the document
    final updateSuccess =
        context.notepadService.updateTab(tabId, content: patchedContent);

    if (!updateSuccess) {
      return jsonEncode({
        'success': false,
        'error': 'Failed to update document after applying patches.',
      });
    }

    if (failCount > 0) {
      return jsonEncode({
        'success': true,
        'tabId': tabId,
        'appliedPatches': successCount,
        'failedPatches': failCount,
        'warning':
            'Some patches could not be applied. $successCount succeeded, $failCount failed.',
      });
    }

    return jsonEncode({
      'success': true,
      'tabId': tabId,
      'appliedPatches': successCount,
      'message': 'All patches applied successfully',
    });
  }
}
