import 'dart:convert';
import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/services/text_agent_service.dart';
import 'package:vagina/services/log_service.dart';

/// Host-side adapter for handling text agent API calls from the isolate sandbox
///
/// Routes hostCall messages from the isolate to appropriate TextAgentService
/// methods and converts responses to sendable values.
class TextAgentHostApi {
  static const _tag = 'TextAgentHostApi';

  final TextAgentService _textAgentService;
  final ConfigRepository _configRepository;
  final LogService _logService;

  TextAgentHostApi({
    required TextAgentService textAgentService,
    required ConfigRepository configRepository,
    LogService? logService,
  })  : _textAgentService = textAgentService,
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
      case 'listAgents':
        return await _handleListAgents(args);
      default:
        _logService.error(_tag, 'Unknown method: $method');
        _logService.error(_tag, 'Request Payload: ${jsonEncode(args)}');
        throw Exception('Unknown method: $method');
    }
  }

  Future<dynamic> _handleSendQuery(
    Map<String, dynamic> args,
  ) async {
    final agentId = args['agentId'] as String?;
    final prompt = args['prompt'] as String?;

    // Validate parameters
    if (agentId == null || agentId.isEmpty) {
      _logService.error(_tag, 'sendQuery - Missing or empty agentId');
      _logService.error(_tag, 'Request Payload: ${jsonEncode(args)}');
      throw Exception('Missing or empty required parameter: agentId');
    }

    if (prompt == null || prompt.trim().isEmpty) {
      _logService.error(_tag, 'sendQuery - Missing or empty prompt');
      _logService.error(_tag, 'Request Payload: ${jsonEncode(args)}');
      throw Exception('Missing or empty required parameter: prompt');
    }

    // Get the agent
    final agent = await _configRepository.getTextAgentById(agentId);
    if (agent == null) {
      _logService.error(_tag, 'sendQuery - Agent not found: $agentId');
      _logService.error(_tag, 'Request Payload: ${jsonEncode(args)}');
      throw Exception('Agent not found: $agentId');
    }

    _logService.info(
      _tag,
      'Processing query for agent ${agent.name}',
    );

    // Execute and return result text
    final result = await _textAgentService.sendQuery(agent, prompt);
    return result;
  }

  Future<dynamic> _handleListAgents(
    Map<String, dynamic> args,
  ) async {
    _logService.debug(_tag, 'Listing available agents');

    final agents = await _configRepository.getAllTextAgents();

    return agents.map((agent) {
      final apiConfig = agent.apiConfig;
      String providerDisplay = 'unknown';
      String provider = 'unknown';
      
      if (apiConfig is SelfhostedTextAgentApiConfig) {
        providerDisplay = '${apiConfig.provider}: ${apiConfig.model}';
        provider = apiConfig.provider;
      } else if (apiConfig is HostedTextAgentApiConfig) {
        providerDisplay = 'Hosted: ${apiConfig.modelId}';
        provider = 'hosted';
      }
      
      return {
        'id': agent.id,
        'name': agent.name,
        'description': agent.description,
        'provider': provider,
        'config': providerDisplay,
      };
    }).toList();
  }
}
