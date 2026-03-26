import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/text_agent_info.dart';
import 'package:vagina/services/log_service.dart';

/// Service for making HTTP calls to OpenAI-compatible Chat Completions APIs
class TextAgentService {
  static const _tag = 'TextAgentService';

  // Default configuration constants
  static const int defaultMaxTokens = 4096;
  static const double defaultTemperature = 1.0;
  static const int defaultTimeoutSeconds = 30;
  static const int httpStatusOk = 200;

  final LogService _logService;
  final http.Client _httpClient;

  TextAgentService({
    LogService? logService,
    http.Client? httpClient,
  })  : _logService = logService ?? LogService(),
        _httpClient = httpClient ?? http.Client();

  /// Send a query that waits for the response synchronously.
  ///
  /// Throws [TimeoutException] if the request times out.
  /// Throws [Exception] for other errors.
  Future<String> sendQuery(
    TextAgentInfo agent,
    String prompt, {
    Duration? timeout,
  }) async {
    if (prompt.trim().isEmpty) {
      throw ArgumentError.value(
        prompt,
        'prompt',
        'Prompt cannot be empty',
      );
    }

    _logService.info(_tag, 'Sending query to agent: ${agent.name}');

    final effectiveTimeout = timeout ?? const Duration(seconds: defaultTimeoutSeconds);

    try {
      final response = await _sendHttpRequest(
        agent,
        prompt,
        timeout: effectiveTimeout,
      );

      _logService.info(
        _tag,
        'Query completed for agent: ${agent.name}',
      );

      return response;
    } catch (e) {
      _logService.error(_tag, 'Query failed: $e');
      rethrow;
    }
  }

  /// Execute HTTP request to OpenAI-compatible Chat Completions API
  Future<String> _sendHttpRequest(
    TextAgentInfo agent,
    String prompt, {
    required Duration timeout,
  }) async {
    final apiConfig = agent.apiConfig;
    
    if (apiConfig is! SelfhostedTextAgentApiConfig) {
      throw UnsupportedError(
        'Only selfhosted text agents are supported in v1 service: ${agent.id}',
      );
    }

    // Build the endpoint URL based on provider
    final url = _buildEndpointUrl(apiConfig);
    final model = apiConfig.model;
    final headers = _buildRequestHeaders(apiConfig);

    _logService.debug(
      _tag,
      'Provider: ${apiConfig.provider}, Model: $model, URL: $url',
    );

    // Build request body
    final requestBody = <String, dynamic>{
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': defaultMaxTokens,
      'temperature': defaultTemperature,
    };

    // Azure identifies the model via the deployment in the URL, not the body.
    if (apiConfig.provider != 'azure') {
      requestBody['model'] = model;
    }

    _logService.debug(
      _tag,
      'Request body: ${jsonEncode(requestBody)}',
    );

    try {
      final response = await _httpClient
          .post(
            url,
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      _logService.debug(
        _tag,
        'Response status: ${response.statusCode}',
      );

      if (response.statusCode != httpStatusOk) {
        final errorBody = response.body;
        _logService.error(
          _tag,
          'HTTP ${response.statusCode}: $errorBody',
        );
        throw Exception(
          'API error (${response.statusCode}): $errorBody',
        );
      }

      // Parse response
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = responseJson['choices'] as List?;

      if (choices == null || choices.isEmpty) {
        throw Exception('No choices in response');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw Exception('No message in response');
      }

      final content = message['content'] as String?;
      if (content == null) {
        throw Exception('No content in response');
      }

      _logService.debug(
        _tag,
        'Response content length: ${content.length}',
      );

      return content;
    } on TimeoutException catch (e) {
      _logService.error(_tag, 'Request timeout: $e');
      throw TimeoutException('Request timeout after ${timeout.inSeconds}s');
    } on http.ClientException catch (e) {
      _logService.error(_tag, 'HTTP client error: $e');
      throw Exception('Network error: $e');
    } catch (e) {
      _logService.error(_tag, 'Unexpected error: $e');
      rethrow;
    }
  }

  Uri _buildEndpointUrl(SelfhostedTextAgentApiConfig config) {
    // For now, construct Chat Completions URL from baseUrl
    final baseUrl = config.baseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$baseUrl/chat/completions');
  }

  Map<String, String> _buildRequestHeaders(SelfhostedTextAgentApiConfig config) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    switch (config.provider) {
      case 'openai':
      case 'litellm':
      case 'custom':
        headers['Authorization'] = 'Bearer ${config.apiKey}';
        break;
      case 'azure':
        headers['api-key'] = config.apiKey;
        break;
      default:
        // Fallback: try both header formats
        headers['Authorization'] = 'Bearer ${config.apiKey}';
        headers['api-key'] = config.apiKey;
    }

    return headers;
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// Provider for TextAgentService
final textAgentServiceProvider = Provider<TextAgentService>((ref) {
  final service = TextAgentService();
  ref.onDispose(() => service.dispose());
  return service;
});
