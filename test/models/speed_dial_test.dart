import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/speed_dial.dart';

void main() {
  group('SpeedDial', () {
    test('should create default speed dial', () {
      final speedDial = SpeedDial.defaultSpeedDial;

      expect(speedDial.id, equals(SpeedDial.defaultId));
      expect(speedDial.name, equals('Default'));
      expect(speedDial.isDefault, isTrue);
      expect(speedDial.voice, equals('alloy'));
      expect(speedDial.systemPrompt, isNotEmpty);
    });

    test('should identify default speed dial correctly', () {
      final defaultDial = SpeedDial.defaultSpeedDial;
      final customDial = SpeedDial(
        id: 'custom-1',
        name: 'Custom',
        systemPrompt: 'Custom prompt',
        voice: 'echo',
      );

      expect(defaultDial.isDefault, isTrue);
      expect(customDial.isDefault, isFalse);
    });

    test('should serialize and deserialize correctly', () {
      final speedDial = SpeedDial(
        id: 'test-1',
        name: 'Test Character',
        systemPrompt: 'Test prompt',
        iconEmoji: '🎭',
        voice: 'shimmer',
        createdAt: DateTime.parse('2026-01-15T12:00:00Z'),
      );

      final json = speedDial.toJson();
      final deserialized = SpeedDial.fromJson(json);

      expect(deserialized.id, equals(speedDial.id));
      expect(deserialized.name, equals(speedDial.name));
      expect(deserialized.systemPrompt, equals(speedDial.systemPrompt));
      expect(deserialized.iconEmoji, equals(speedDial.iconEmoji));
      expect(deserialized.voice, equals(speedDial.voice));
      expect(deserialized.createdAt, equals(speedDial.createdAt));
    });

    test('should handle null iconEmoji in JSON', () {
      final json = {
        'id': 'test-1',
        'name': 'Test',
        'systemPrompt': 'Prompt',
        'voice': 'alloy',
      };

      final speedDial = SpeedDial.fromJson(json);
      expect(speedDial.iconEmoji, isNull);
    });

    test('should use default voice if not provided in JSON', () {
      final json = {
        'id': 'test-1',
        'name': 'Test',
        'systemPrompt': 'Prompt',
      };

      final speedDial = SpeedDial.fromJson(json);
      expect(speedDial.voice, equals('alloy'));
    });

    test('should copy with modifications', () {
      final original = SpeedDial(
        id: 'test-1',
        name: 'Original',
        systemPrompt: 'Original prompt',
        voice: 'alloy',
      );

      final modified = original.copyWith(
        name: 'Modified',
        voice: 'echo',
      );

      expect(modified.id, equals(original.id));
      expect(modified.name, equals('Modified'));
      expect(modified.systemPrompt, equals(original.systemPrompt));
      expect(modified.voice, equals('echo'));
    });
  });
}
