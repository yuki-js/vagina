import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/tools/base_tool.dart';
import 'package:vagina/services/tools/tool_metadata.dart';
import 'package:vagina/services/tools_runtime/legacy_base_tool_adapter.dart';
import 'package:vagina/services/tools_runtime/notepad_backend.dart';
import 'package:vagina/services/tools_runtime/tool_context.dart';

class _FakeLegacyTool extends BaseTool {
  @override
  String get name => 'fake_tool';

  @override
  String get description => 'Fake legacy tool for adapter test.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'value': {'type': 'string'},
        },
        'required': ['value'],
      };

  @override
  ToolMetadata get metadata => const ToolMetadata(
        name: 'fake_tool',
        displayName: 'フェイク',
        displayDescription: 'テスト用のツールです',
        description: 'Fake legacy tool for adapter test.',
        iconKey: 'extension',
        category: ToolCategory.custom,
        source: ToolSource.custom,
        mcpServerUrl: 'https://example.invalid/mcp',
      );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final value = arguments['value'] as String;
    if (value == 'throw') {
      throw StateError('boom');
    }

    return {
      'success': true,
      'echo': value,
    };
  }
}

void main() {
  group('LegacyBaseToolAdapter', () {
    test('maps definition fields from legacy tool metadata', () {
      final adapter = LegacyBaseToolAdapter(_FakeLegacyTool());

      expect(adapter.definition.toolKey, 'fake_tool');
      expect(adapter.definition.displayName, 'フェイク');
      expect(adapter.definition.displayDescription, 'テスト用のツールです');
      expect(adapter.definition.categoryKey, ToolCategory.custom.name);
      expect(adapter.definition.iconKey, 'extension');
      expect(adapter.definition.sourceKey, ToolSource.custom.name);
      expect(adapter.definition.mcpServerUrl, 'https://example.invalid/mcp');
      expect(adapter.definition.description, 'Fake legacy tool for adapter test.');
      expect(adapter.definition.parametersSchema['type'], 'object');
    });

    test('execute returns legacy-style JSON string on success', () async {
      final adapter = LegacyBaseToolAdapter(_FakeLegacyTool());
      final ctx = ToolContext(notepadBackend: NotepadBackend());

      final out = await adapter.execute({'value': 'hi'}, ctx);

      final decoded = jsonDecode(out) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      expect(decoded['echo'], 'hi');
    });

    test('execute returns legacy-style JSON string on error', () async {
      final adapter = LegacyBaseToolAdapter(_FakeLegacyTool());
      final ctx = ToolContext(notepadBackend: NotepadBackend());

      final out = await adapter.execute({'value': 'throw'}, ctx);

      final decoded = jsonDecode(out) as Map<String, dynamic>;
      expect(decoded['error'], contains('boom'));
    });
  });
}
