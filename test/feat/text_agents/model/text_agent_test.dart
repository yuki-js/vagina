import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';

void main() {
  group('TextAgent Model - enabledTools', () {
    // Helper to create a test config
    TextAgentConfig createTestConfig() {
      return const TextAgentConfig(
        provider: TextAgentProvider.openai,
        apiKey: 'test-key',
        apiIdentifier: 'gpt-4o',
      );
    }

    test('toJson() should correctly serialize enabledTools', () {
      // Arrange
      final now = DateTime.now();
      final agent = TextAgent(
        id: 'agent-1',
        name: 'Test Agent',
        description: 'Test description',
        config: createTestConfig(),
        enabledTools: const {
          'tool1': true,
          'tool2': false,
          'tool3': true,
        },
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final json = agent.toJson();

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
      final now = DateTime.now();
      final json = {
        'id': 'agent-2',
        'name': 'Test Agent 2',
        'description': 'Test description 2',
        'config': {
          'provider': 'openai',
          'apiKey': 'test-key-2',
          'apiIdentifier': 'gpt-4o',
        },
        'enabledTools': {
          'toolA': true,
          'toolB': false,
          'toolC': true,
        },
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      // Act
      final agent = TextAgent.fromJson(json);

      // Assert
      expect(agent.enabledTools, isA<Map<String, bool>>());
      expect(agent.enabledTools['toolA'], true);
      expect(agent.enabledTools['toolB'], false);
      expect(agent.enabledTools['toolC'], true);
      expect(agent.enabledTools.length, 3);
    });

    test('fromJson() should fallback to empty Map when enabledTools key is missing (backward compatibility)', () {
      // Arrange
      final now = DateTime.now();
      final json = {
        'id': 'agent-3',
        'name': 'Legacy Agent',
        'description': 'Legacy description',
        'config': {
          'provider': 'openai',
          'apiKey': 'legacy-key',
          'apiIdentifier': 'gpt-4',
        },
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        // No enabledTools key - simulating legacy data
      };

      // Act
      final agent = TextAgent.fromJson(json);

      // Assert
      expect(agent.enabledTools, isA<Map<String, bool>>());
      expect(agent.enabledTools.isEmpty, true);
      expect(agent.enabledTools, const <String, bool>{});
    });

    test('fromJson() should fallback to empty Map when enabledTools is null', () {
      // Arrange
      final now = DateTime.now();
      final json = {
        'id': 'agent-4',
        'name': 'Null Tools Agent',
        'description': 'Test description',
        'config': {
          'provider': 'openai',
          'apiKey': 'test-key',
          'apiIdentifier': 'gpt-4o',
        },
        'enabledTools': null,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      // Act
      final agent = TextAgent.fromJson(json);

      // Assert
      expect(agent.enabledTools, isA<Map<String, bool>>());
      expect(agent.enabledTools.isEmpty, true);
    });

    test('copyWith() should correctly copy enabledTools', () {
      // Arrange
      final now = DateTime.now();
      final original = TextAgent(
        id: 'agent-5',
        name: 'Original Agent',
        config: createTestConfig(),
        enabledTools: const {
          'tool1': true,
          'tool2': false,
        },
        createdAt: now,
        updatedAt: now,
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
      final now = DateTime.now();
      final original = TextAgent(
        id: 'agent-6',
        name: 'Original Agent',
        config: createTestConfig(),
        enabledTools: const {
          'tool1': true,
          'tool2': false,
        },
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final copied = original.copyWith(name: 'Modified Agent');

      // Assert
      expect(copied.enabledTools, original.enabledTools);
      expect(copied.enabledTools['tool1'], true);
      expect(copied.enabledTools['tool2'], false);
      expect(copied.name, 'Modified Agent');
    });

    test('round-trip serialization should preserve enabledTools', () {
      // Arrange
      final now = DateTime.now();
      final original = TextAgent(
        id: 'agent-7',
        name: 'Round Trip Agent',
        description: 'Round trip test',
        config: createTestConfig(),
        enabledTools: const {
          'tool1': true,
          'tool2': false,
          'tool3': true,
          'tool4': false,
        },
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final json = original.toJson();
      final deserialized = TextAgent.fromJson(json);

      // Assert
      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.description, original.description);
      expect(deserialized.enabledTools, original.enabledTools);
      expect(deserialized.enabledTools['tool1'], true);
      expect(deserialized.enabledTools['tool2'], false);
      expect(deserialized.enabledTools['tool3'], true);
      expect(deserialized.enabledTools['tool4'], false);
    });

    test('fromJson() should handle legacy Azure format and preserve enabledTools', () {
      // Arrange
      final now = DateTime.now();
      final json = {
        'id': 'agent-8',
        'name': 'Legacy Azure Agent',
        'description': 'Legacy Azure test',
        'config': {
          // Legacy Azure format (no 'provider' key)
          'endpoint': 'https://test.openai.azure.com',
          'apiKey': 'azure-key',
          'deploymentName': 'gpt-4',
        },
        'enabledTools': {
          'toolX': true,
          'toolY': false,
        },
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      // Act
      final agent = TextAgent.fromJson(json);

      // Assert
      expect(agent.id, 'agent-8');
      expect(agent.name, 'Legacy Azure Agent');
      expect(agent.enabledTools['toolX'], true);
      expect(agent.enabledTools['toolY'], false);
      expect(agent.config.provider, TextAgentProvider.azure); // Should be migrated to new format
    });

    test('default enabledTools should be empty Map', () {
      // Arrange
      final now = DateTime.now();
      final agent = TextAgent(
        id: 'agent-9',
        name: 'Default Agent',
        config: createTestConfig(),
        createdAt: now,
        updatedAt: now,
        // enabledTools not specified, should use default
      );

      // Assert
      expect(agent.enabledTools, isA<Map<String, bool>>());
      expect(agent.enabledTools.isEmpty, true);
      expect(agent.enabledTools, const <String, bool>{});
    });
  });
}
