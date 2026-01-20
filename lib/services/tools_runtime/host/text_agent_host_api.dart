import 'dart:convert';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/services/text_agent_job_runner.dart';
import 'package:vagina/services/log_service.dart';

/// Host-side adapter for handling text agent API calls from the isolate sandbox
///
/// Routes hostCall messages from the isolate to appropriate TextAgentService
/// and TextAgentJobRunner methods and converts responses to sendable Maps
class TextAgentHostApi {
  static const _tag = 'TextAgentHostApi';

  final TextAgentService _textAgentService;
  final TextAgentJobRunner _jobRunner;
  final ConfigRepository _configRepository;
  final LogService _logService;

  TextAgentHostApi({
    required TextAgentService textAgentService,
    required TextAgentJobRunner jobRunner,
    required ConfigRepository configRepository,
    LogService? logService,
  })  : _textAgentService = textAgentService,
        _jobRunner = jobRunner,
        _configRepository = configRepository,
        _logService = logService ?? LogService();

  /// Handle API calls from the isolate
  ///
  /// Routes to appropriate methods based on [method] parameter
  /// and throws on error
  Future<dynamic> handleCall(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'sendQuery':
        return await _handleSendQuery(args);
      case 'getResult':
        return await _handleGetResult(args);
      case 'listAgents':
        return await _handleListAgents(args);
      default:
        print('[$_tag:HOST] Unknown method: $method');
        print('Request Payload: ${jsonEncode(args)}');
        throw Exception('Unknown method: $method');
    }
  }

  Future<dynamic> _handleSendQuery(
    Map<String, dynamic> args,
  ) async {
    final agentId = args['agentId'] as String?;
    final prompt = args['prompt'] as String?;
    final expectLatencyStr = args['expectLatency'] as String?;

    // Validate parameters
    if (agentId == null || agentId.isEmpty) {
      print('[$_tag:HOST] sendQuery - Missing or empty agentId');
      print('Request Payload: ${jsonEncode(args)}');
      throw Exception('Missing or empty required parameter: agentId');
    }

    if (prompt == null || prompt.trim().isEmpty) {
      print('[$_tag:HOST] sendQuery - Missing or empty prompt');
      print('Request Payload: ${jsonEncode(args)}');
      throw Exception('Missing or empty required parameter: prompt');
    }

    if (expectLatencyStr == null) {
      print('[$_tag:HOST] sendQuery - Missing expectLatency');
      print('Request Payload: ${jsonEncode(args)}');
      throw Exception('Missing required parameter: expectLatency');
    }

    // Parse expectLatency
    TextAgentExpectLatency expectLatency;
    try {
      expectLatency = TextAgentExpectLatency.fromString(expectLatencyStr);
    } catch (e) {
      print('[$_tag:HOST] sendQuery - Invalid expectLatency: $expectLatencyStr');
      print('Request Payload: ${jsonEncode(args)}');
      throw Exception(
        'Invalid expectLatency value: $expectLatencyStr. '
        'Must be one of: instant, long, ultra_long',
      );
    }

    // Get the agent
    final agent = await _configRepository.getTextAgentById(agentId);
    if (agent == null) {
      print('[$_tag:HOST] sendQuery - Agent not found: $agentId');
      print('Request Payload: ${jsonEncode(args)}');
      throw Exception('Agent not found: $agentId');
    }

    _logService.info(
      _tag,
      'Processing query for agent ${agent.name} with latency ${expectLatency.value}',
    );

    // Handle based on latency
    if (expectLatency == TextAgentExpectLatency.instant) {
      // Execute instantly and return result
      final result = await _textAgentService.sendInstantQuery(agent, prompt);
      return {
        'mode': 'instant',
        'text': result,
        'agentId': agentId,
      };
    } else {
      // Submit async job and return token
      final token = await _jobRunner.submitJob(agent, prompt, expectLatency);
      
      // Determine poll interval based on latency
      final pollAfterMs = expectLatency == TextAgentExpectLatency.long
          ? 1500
          : 3000;

      return {
        'mode': 'async',
        'token': token,
        'agentId': agentId,
        'pollAfterMs': pollAfterMs,
      };
    }
  }

  Future<dynamic> _handleGetResult(
    Map<String, dynamic> args,
  ) async {
    final token = args['token'] as String?;

    if (token == null || token.isEmpty) {
      print('[$_tag:HOST] getResult - Missing or empty token');
      print('Request Payload: ${jsonEncode(args)}');
      throw Exception('Missing or empty required parameter: token');
    }

    _logService.debug(_tag, 'Getting result for token: $token');

    // Get job status
    final job = await _jobRunner.getJobStatus(token);
    if (job == null) {
      print('[$_tag:HOST] getResult - Job not found: $token');
      print('Request Payload: ${jsonEncode(args)}');
      throw Exception('Job not found: $token');
    }

    // Return status based on job state
    switch (job.status) {
      case TextAgentJobStatus.completed:
        return {
          'status': 'succeeded',
          'text': job.result ?? '',
        };

      case TextAgentJobStatus.failed:
        print('[$_tag:HOST] getResult - Job failed: $token');
        print('Error: ${job.error}');
        throw Exception('Job failed: ${job.error ?? "Unknown error"}');

      case TextAgentJobStatus.expired:
        print('[$_tag:HOST] getResult - Job expired: $token');
        throw Exception('Job expired');

      case TextAgentJobStatus.pending:
      case TextAgentJobStatus.running:
        // Determine poll interval based on latency
        final pollAfterMs = job.expectLatency == TextAgentExpectLatency.long
            ? 1500
            : 3000;

        return {
          'status': job.status.value,
          'pollAfterMs': pollAfterMs,
        };
    }
  }

  Future<dynamic> _handleListAgents(
    Map<String, dynamic> args,
  ) async {
    _logService.debug(_tag, 'Listing available agents');

    final agents = await _configRepository.getAllTextAgents();
    
    return agents.map((agent) {
      return {
        'id': agent.id,
        'name': agent.name,
        'description': agent.description ?? '',
        'provider': agent.config.provider.value,
        'config': agent.config.getDisplayString(),
      };
    }).toList();
  }
}
