import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/models/text_agent.dart';
import 'package:vagina/repositories/local_text_agent_repository.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// Mock path provider for testing
class MockPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTemp('vagina_test').then((dir) => dir.path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalTextAgentRepository', () {
    late LocalTextAgentRepository repository;
    late Directory tempDir;

    setUp(() async {
      PathProviderPlatform.instance = MockPathProviderPlatform();
      repository = LocalTextAgentRepository();
      tempDir = await Directory.systemTemp.createTemp('vagina_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should return empty list when no agents exist', () async {
      final agents = await repository.getAll();
      expect(agents, isEmpty);
    });

    test('should save and retrieve agent', () async {
      const agent = TextAgent(
        id: 'test-agent',
        name: 'Test Agent',
        description: 'Test description',
        modelIdentifier: 'test-model',
      );

      await repository.save(agent);
      final retrieved = await repository.getById('test-agent');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, agent.id);
      expect(retrieved.name, agent.name);
    });

    test('should update existing agent', () async {
      const agent = TextAgent(
        id: 'test-agent',
        name: 'Original Name',
        description: 'Original description',
        modelIdentifier: 'test-model',
      );

      await repository.save(agent);

      final updated = agent.copyWith(name: 'Updated Name');
      await repository.save(updated);

      final retrieved = await repository.getById('test-agent');
      expect(retrieved!.name, 'Updated Name');
    });

    test('should delete agent', () async {
      const agent = TextAgent(
        id: 'test-agent',
        name: 'Test Agent',
        description: 'Test description',
        modelIdentifier: 'test-model',
      );

      await repository.save(agent);
      await repository.delete('test-agent');

      final retrieved = await repository.getById('test-agent');
      expect(retrieved, isNull);
    });

    test('should check if agent exists', () async {
      const agent = TextAgent(
        id: 'test-agent',
        name: 'Test Agent',
        description: 'Test description',
        modelIdentifier: 'test-model',
      );

      expect(await repository.exists('test-agent'), isFalse);

      await repository.save(agent);
      expect(await repository.exists('test-agent'), isTrue);

      await repository.delete('test-agent');
      expect(await repository.exists('test-agent'), isFalse);
    });

    test('should save multiple agents', () async {
      const agent1 = TextAgent(
        id: 'agent-1',
        name: 'Agent 1',
        description: 'First agent',
        modelIdentifier: 'model-1',
      );

      const agent2 = TextAgent(
        id: 'agent-2',
        name: 'Agent 2',
        description: 'Second agent',
        modelIdentifier: 'model-2',
      );

      await repository.save(agent1);
      await repository.save(agent2);

      final agents = await repository.getAll();
      expect(agents.length, 2);
      expect(agents.any((a) => a.id == 'agent-1'), isTrue);
      expect(agents.any((a) => a.id == 'agent-2'), isTrue);
    });
  });
}
