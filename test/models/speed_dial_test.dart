import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/speed_dial.dart';

void main() {
  group('SpeedDial Model - enabledTools', () {
    test('toJson() should correctly serialize enabledTools', () {
      // Arrange
      final speedDial = SpeedDial(
        id: 'test-1',
        name: 'Test Agent',
        systemPrompt: 'Test prompt',
        voice: 'alloy',
        enabledTools: const {
          'tool1': true,
          'tool2': false,
          'tool3': true,
        },
      );

      // Act
      final json = speedDial.toJson();

      // Assert
      expect(json['enabledTools'], isA<Map<String, bool>>());
      expect(json['enabledTools'], {
        'tool1': true,
        'tool2': false,
        'tool3': true,
      });
    });

    test('fromJson() should correctly deserialize enabledTools', () {
      // Arrange
      final json = {
        'id': 'test-2',
        'name': 'Test Agent 2',
        'systemPrompt': 'Test prompt 2',
        'voice': 'echo',
        'enabledTools': {
          'toolA': true,
          'toolB': false,
        },
      };

      // Act
      final speedDial = SpeedDial.fromJson(json);

      // Assert
      expect(speedDial.enabledTools, isA<Map<String, bool>>());
      expect(speedDial.enabledTools['toolA'], true);
      expect(speedDial.enabledTools['toolB'], false);
      expect(speedDial.enabledTools.length, 2);
    });

    test(
        'fromJson() should fallback to empty Map when enabledTools key is missing',
        () {
      // Arrange
      final json = {
        'id': 'test-3',
        'name': 'Legacy Agent',
        'systemPrompt': 'Legacy prompt',
        'voice': 'alloy',
        // No enabledTools key
      };

      // Act
      final speedDial = SpeedDial.fromJson(json);

      // Assert
      expect(speedDial.enabledTools, isA<Map<String, bool>>());
      expect(speedDial.enabledTools.isEmpty, true);
      expect(speedDial.enabledTools, const <String, bool>{});
    });

    test('fromJson() should fallback to empty Map when enabledTools is null',
        () {
      // Arrange
      final json = {
        'id': 'test-4',
        'name': 'Null Tools Agent',
        'systemPrompt': 'Test prompt',
        'voice': 'alloy',
        'enabledTools': null,
      };

      // Act
      final speedDial = SpeedDial.fromJson(json);

      // Assert
      expect(speedDial.enabledTools, isA<Map<String, bool>>());
      expect(speedDial.enabledTools.isEmpty, true);
    });

    test('copyWith() should correctly copy enabledTools', () {
      // Arrange
      final original = SpeedDial(
        id: 'test-5',
        name: 'Original',
        systemPrompt: 'Original prompt',
        voice: 'alloy',
        enabledTools: const {
          'tool1': true,
          'tool2': false,
        },
      );

      final newTools = {
        'tool1': false,
        'tool2': true,
        'tool3': true,
      };

      // Act
      final copied = original.copyWith(enabledTools: newTools);

      // Assert
      expect(copied.enabledTools, newTools);
      expect(copied.enabledTools['tool1'], false);
      expect(copied.enabledTools['tool2'], true);
      expect(copied.enabledTools['tool3'], true);

      // Original should remain unchanged
      expect(original.enabledTools['tool1'], true);
      expect(original.enabledTools['tool2'], false);
      expect(original.enabledTools.containsKey('tool3'), false);
    });

    test('copyWith() should preserve enabledTools when not specified', () {
      // Arrange
      final original = SpeedDial(
        id: 'test-6',
        name: 'Original',
        systemPrompt: 'Original prompt',
        voice: 'alloy',
        enabledTools: const {
          'tool1': true,
          'tool2': false,
        },
      );

      // Act
      final copied = original.copyWith(name: 'Modified');

      // Assert
      expect(copied.enabledTools, original.enabledTools);
      expect(copied.enabledTools['tool1'], true);
      expect(copied.enabledTools['tool2'], false);
    });

    test('defaultSpeedDial should have empty enabledTools Map', () {
      // Act
      final defaultDial = SpeedDial.defaultSpeedDial;

      // Assert
      expect(defaultDial.enabledTools, isA<Map<String, bool>>());
      expect(defaultDial.enabledTools.isEmpty, true);
      expect(defaultDial.enabledTools, const <String, bool>{});
      expect(defaultDial.id, SpeedDial.defaultId);
      expect(defaultDial.name, 'Default');
    });

    test('isDefault should return true for default speed dial', () {
      // Act
      final defaultDial = SpeedDial.defaultSpeedDial;

      // Assert
      expect(defaultDial.isDefault, true);
    });

    test('isDefault should return false for custom speed dial', () {
      // Arrange
      final customDial = SpeedDial(
        id: 'custom-1',
        name: 'Custom',
        systemPrompt: 'Custom prompt',
        enabledTools: const {},
      );

      // Assert
      expect(customDial.isDefault, false);
    });

    test('round-trip serialization should preserve enabledTools', () {
      // Arrange
      final original = SpeedDial(
        id: 'test-7',
        name: 'Round Trip',
        systemPrompt: 'Round trip test',
        voice: 'shimmer',
        enabledTools: const {
          'tool1': true,
          'tool2': false,
          'tool3': true,
          'tool4': false,
        },
      );

      // Act
      final json = original.toJson();
      final deserialized = SpeedDial.fromJson(json);

      // Assert
      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.systemPrompt, original.systemPrompt);
      expect(deserialized.voice, original.voice);
      expect(deserialized.enabledTools, original.enabledTools);
      expect(deserialized.enabledTools['tool1'], true);
      expect(deserialized.enabledTools['tool2'], false);
      expect(deserialized.enabledTools['tool3'], true);
      expect(deserialized.enabledTools['tool4'], false);
    });
  });
}
