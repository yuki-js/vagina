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

  group('ToolDefinition.realtimeParametersSchema normalizer (Fix 2)', () {
    ToolDefinition makeDef(Map<String, dynamic> schema) => ToolDefinition(
          toolKey: 'test',
          displayName: 'T',
          displayDescription: 'd',
          categoryKey: 'c',
          iconKey: 'i',
          sourceKey: 's',
          publishedBy: 'p',
          description: 'desc',
          parametersSchema: schema,
        );

    test('empty schema {} → {type:object, properties:{}}', () {
      final def = makeDef({});
      final result = def.realtimeParametersSchema;
      expect(result['type'], equals('object'));
      expect(result['properties'], isA<Map>());
      expect((result['properties'] as Map).isEmpty, isTrue);
    });

    test('schema with no type → type set to object', () {
      final def = makeDef({'properties': {'x': {'type': 'string'}}});
      final result = def.realtimeParametersSchema;
      expect(result['type'], equals('object'));
      expect(result['properties'], isNotNull);
    });

    test('type=object with no properties → properties:{} added', () {
      final def = makeDef({'type': 'object'});
      final result = def.realtimeParametersSchema;
      expect(result['type'], equals('object'));
      expect(result['properties'], isA<Map>());
      expect((result['properties'] as Map).isEmpty, isTrue);
    });

    test('type=object with empty properties const map → preserved as-is', () {
      // This is the fs_active_files case: parametersSchema already has both keys
      const schema = <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      };
      final def = makeDef(schema);
      final result = def.realtimeParametersSchema;
      expect(result['type'], equals('object'));
      expect(result['properties'], isA<Map>());
      expect((result['properties'] as Map).isEmpty, isTrue);
    });

    test('valid schema with properties is returned as-is (no mutation)', () {
      final schema = <String, dynamic>{
        'type': 'object',
        'properties': {
          'city': {'type': 'string'},
        },
        'required': ['city'],
      };
      final def = makeDef(schema);
      final result = def.realtimeParametersSchema;
      expect(result['type'], equals('object'));
      expect((result['properties'] as Map).containsKey('city'), isTrue);
      expect(result['required'], equals(['city']));
    });

    test('type != object is returned as-is (no strict-ification)', () {
      final schema = <String, dynamic>{
        'type': 'string',
      };
      final def = makeDef(schema);
      final result = def.realtimeParametersSchema;
      expect(result['type'], equals('string'));
      // should NOT add properties to a non-object schema
      expect(result.containsKey('properties'), isFalse);
    });

    test('toRealtimeJson uses normalized schema', () {
      final def = makeDef({});
      final json = def.toRealtimeJson();
      final params = json['parameters'] as Map;
      expect(params['type'], equals('object'));
      expect(params['properties'], isA<Map>());
    });
  });
}
