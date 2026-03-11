import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/services/tools_runtime/tool_definition.dart';

void main() {
  group('ToolActivation', () {
    test('always activation is enabled regardless of extensions', () {
      const activation = ToolActivation.always();
      expect(activation.isEnabledForExtensions(<String>{}), isTrue);
      expect(
        activation.isEnabledForExtensions({'.txt', '.v2d.csv'}),
        isTrue,
      );
    });

    test('extension activation matches configured extension only', () {
      const activation = ToolActivation.forExtensions([
        '.md',
        '.txt',
      ]);

      expect(activation.isEnabledForExtensions({'.txt'}), isTrue);
      expect(activation.isEnabledForExtensions({'.csv'}), isFalse);
    });

    test('extension activation is case-insensitive', () {
      const activation = ToolActivation.forExtensions(['.v2d.json']);
      expect(activation.isEnabledForExtensions({'.V2D.JSON'}), isTrue);
    });
  });

  group('ToolDefinition serialization', () {
    test('toJson/fromJson preserves activation', () {
      const definition = ToolDefinition(
        toolKey: 'test_tool',
        displayName: 'Test',
        displayDescription: 'desc',
        categoryKey: 'custom',
        iconKey: 'extension',
        sourceKey: 'builtin',
        publishedBy: 'aokiapp',
        description: 'test',
        activation: ToolActivation.forExtensions(['.md']),
        parametersSchema: {
          'type': 'object',
          'properties': {},
        },
      );

      final serialized = definition.toJson();
      final restored = ToolDefinition.fromJson(serialized);

      expect(restored.activation.alwaysAvailable, isFalse);
      expect(restored.activation.extensions, ['.md']);
    });
  });
}
