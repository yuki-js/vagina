import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';

void main() {
  group('TextAgentConfig', () {
    test('toJson and fromJson should work correctly with Azure provider', () {
      final config = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-api-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );

      final json = config.toJson();
      final decoded = TextAgentConfig.fromJson(json);

      expect(decoded.provider, config.provider);
      expect(decoded.apiKey, config.apiKey);
      expect(decoded.apiIdentifier, config.apiIdentifier);
    });

    test('toJson and fromJson should work correctly with OpenAI provider', () {
      final config = TextAgentConfig(
        provider: TextAgentProvider.openai,
        apiKey: 'test-api-key',
        apiIdentifier: 'gpt-4o',
      );

      final json = config.toJson();
      final decoded = TextAgentConfig.fromJson(json);

      expect(decoded.provider, config.provider);
      expect(decoded.apiKey, config.apiKey);
      expect(decoded.apiIdentifier, config.apiIdentifier);
    });

    test('getDisplayString should format correctly', () {
      final azureConfig = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'key',
        apiIdentifier: 'https://example.openai.azure.com',
      );
      expect(azureConfig.getDisplayString(), contains('Azure'));
      expect(azureConfig.getDisplayString(), contains('example.openai.azure.com'));

      final openaiConfig = TextAgentConfig(
        provider: TextAgentProvider.openai,
        apiKey: 'key',
        apiIdentifier: 'gpt-4o',
      );
      expect(openaiConfig.getDisplayString(), 'gpt-4o');
    });

    test('getEndpointUrl should return correct URLs for each provider', () {
      final azureConfig = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'key',
        apiIdentifier: 'https://example.openai.azure.com',
      );
      expect(
        azureConfig.getEndpointUrl(),
        contains('https://example.openai.azure.com/openai/deployments/default/chat/completions'),
      );

      final openaiConfig = TextAgentConfig(
        provider: TextAgentProvider.openai,
        apiKey: 'key',
        apiIdentifier: 'gpt-4o',
      );
      expect(
        openaiConfig.getEndpointUrl(),
        'https://api.openai.com/v1/chat/completions',
      );
    });

    test('getRequestHeaders should include correct auth header for each provider', () {
      final azureConfig = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );
      final azureHeaders = azureConfig.getRequestHeaders();
      expect(azureHeaders['api-key'], 'test-key');

      final openaiConfig = TextAgentConfig(
        provider: TextAgentProvider.openai,
        apiKey: 'test-key',
        apiIdentifier: 'gpt-4o',
      );
      final openaiHeaders = openaiConfig.getRequestHeaders();
      expect(openaiHeaders['Authorization'], 'Bearer test-key');
    });
  });

  group('TextAgent', () {
    test('toJson and fromJson should work correctly with new config', () {
      final now = DateTime.now();
      final config = TextAgentConfig(
        provider: TextAgentProvider.azure,
        apiKey: 'test-api-key',
        apiIdentifier: 'https://example.openai.azure.com',
      );

      final agent = TextAgent(
        id: 'agent-1',
        name: 'Test Agent',
        description: 'A test agent',
        config: config,
        createdAt: now,
        updatedAt: now,
      );

      final json = agent.toJson();
      final decoded = TextAgent.fromJson(json);

      expect(decoded.id, agent.id);
      expect(decoded.name, agent.name);
      expect(decoded.description, agent.description);
      expect(decoded.config.provider, agent.config.provider);
      expect(decoded.config.apiKey, agent.config.apiKey);
      expect(decoded.createdAt.toIso8601String(), agent.createdAt.toIso8601String());
      expect(decoded.updatedAt.toIso8601String(), agent.updatedAt.toIso8601String());
    });

    test('should migrate from legacy Azure format', () {
      final legacyJson = {
        'id': 'agent-1',
        'name': 'Test Agent',
        'description': 'A test agent',
        'config': {
          'endpoint': 'https://example.openai.azure.com',
          'apiKey': 'test-api-key',
          'apiVersion': '2024-10-01-preview',
          'deploymentName': 'gpt-4o-mini',
          'modelName': 'gpt-4o-mini',
          'maxTokens': 4096,
          'temperature': 1.0,
        },
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final agent = TextAgent.fromJson(legacyJson);

      expect(agent.config.provider, TextAgentProvider.azure);
      expect(agent.config.apiKey, 'test-api-key');
      expect(agent.config.apiIdentifier, 'https://example.openai.azure.com');
    });

    test('copyWith should work correctly', () {
      final now = DateTime.now();
      final config = TextAgentConfig(
        provider: TextAgentProvider.openai,
        apiKey: 'test-api-key',
        apiIdentifier: 'gpt-4o',
      );

      final agent = TextAgent(
        id: 'agent-1',
        name: 'Test Agent',
        description: 'A test agent',
        config: config,
        createdAt: now,
        updatedAt: now,
      );

      final updated = agent.copyWith(name: 'Updated Agent');

      expect(updated.id, agent.id);
      expect(updated.name, 'Updated Agent');
      expect(updated.description, agent.description);
    });
  });

  group('TextAgentJob', () {
    test('toJson and fromJson should work correctly', () {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));

      final job = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Test prompt',
        expectLatency: TextAgentExpectLatency.long,
        status: TextAgentJobStatus.pending,
        createdAt: now,
        expiresAt: expiresAt,
      );

      final json = job.toJson();
      final decoded = TextAgentJob.fromJson(json);

      expect(decoded.id, job.id);
      expect(decoded.agentId, job.agentId);
      expect(decoded.prompt, job.prompt);
      expect(decoded.expectLatency, job.expectLatency);
      expect(decoded.status, job.status);
      expect(decoded.createdAt.toIso8601String(), job.createdAt.toIso8601String());
      expect(decoded.expiresAt.toIso8601String(), job.expiresAt.toIso8601String());
    });

    test('toJson and fromJson with result should work correctly', () {
      final now = DateTime.now();
      final completedAt = now.add(const Duration(seconds: 30));
      final expiresAt = now.add(const Duration(hours: 1));

      final job = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Test prompt',
        expectLatency: TextAgentExpectLatency.instant,
        status: TextAgentJobStatus.completed,
        result: 'Test result',
        createdAt: now,
        completedAt: completedAt,
        expiresAt: expiresAt,
      );

      final json = job.toJson();
      final decoded = TextAgentJob.fromJson(json);

      expect(decoded.result, job.result);
      expect(decoded.status, TextAgentJobStatus.completed);
      expect(decoded.completedAt?.toIso8601String(), job.completedAt?.toIso8601String());
    });

    test('toJson and fromJson with error should work correctly', () {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));

      final job = TextAgentJob(
        id: 'job-1',
        agentId: 'agent-1',
        prompt: 'Test prompt',
        expectLatency: TextAgentExpectLatency.ultraLong,
        status: TextAgentJobStatus.failed,
        error: 'Test error',
        createdAt: now,
        expiresAt: expiresAt,
      );

      final json = job.toJson();
      final decoded = TextAgentJob.fromJson(json);

      expect(decoded.error, job.error);
      expect(decoded.status, TextAgentJobStatus.failed);
    });

    test('TextAgentExpectLatency enum should serialize correctly', () {
      expect(TextAgentExpectLatency.instant.value, 'instant');
      expect(TextAgentExpectLatency.long.value, 'long');
      expect(TextAgentExpectLatency.ultraLong.value, 'ultra_long');

      expect(TextAgentExpectLatency.fromString('instant'), TextAgentExpectLatency.instant);
      expect(TextAgentExpectLatency.fromString('long'), TextAgentExpectLatency.long);
      expect(TextAgentExpectLatency.fromString('ultra_long'), TextAgentExpectLatency.ultraLong);
    });

    test('TextAgentJobStatus enum should serialize correctly', () {
      expect(TextAgentJobStatus.pending.value, 'pending');
      expect(TextAgentJobStatus.running.value, 'running');
      expect(TextAgentJobStatus.completed.value, 'completed');
      expect(TextAgentJobStatus.failed.value, 'failed');
      expect(TextAgentJobStatus.expired.value, 'expired');

      expect(TextAgentJobStatus.fromString('pending'), TextAgentJobStatus.pending);
      expect(TextAgentJobStatus.fromString('running'), TextAgentJobStatus.running);
      expect(TextAgentJobStatus.fromString('completed'), TextAgentJobStatus.completed);
      expect(TextAgentJobStatus.fromString('failed'), TextAgentJobStatus.failed);
      expect(TextAgentJobStatus.fromString('expired'), TextAgentJobStatus.expired);
    });
  });
}
