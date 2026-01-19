import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/model/text_agent_job.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/services/log_service.dart';

/// Service for making HTTP calls to OpenAI-compatible Chat Completions APIs
class TextAgentService {
  static const _tag = 'TextAgentService';

  final LogService _logService;
  final http.Client _httpClient;

  TextAgentService({
    LogService? logService,
    http.Client? httpClient,
  })  : _logService = logService ?? LogService(),
        _httpClient = httpClient ?? http.Client();

  /// Send an instant query that waits for the response synchronously
  ///
  /// Throws [TimeoutException] if the request times out
  /// Throws [Exception] for other errors
  Future<String> sendInstantQuery(
    TextAgent agent,
    String prompt, {
    Duration? timeout,
  }) async {
    _logService.info(_tag, 'Sending instant query to agent: ${agent.name}');

    final effectiveTimeout = timeout ?? const Duration(seconds: 30);

    try {
      final response = await _sendHttpRequest(
        agent,
        prompt,
        timeout: effectiveTimeout,
      );

      _logService.info(
        _tag,
        'Instant query completed for agent: ${agent.name}',
      );

      return response;
    } catch (e) {
      _logService.error(_tag, 'Instant query failed: $e');
      rethrow;
    }
  }

  /// Send an async query that returns immediately with a job token
  ///
  /// The actual query execution should be handled by the job runner
  /// This method only validates the request
  Future<String> sendAsyncQuery(
    TextAgent agent,
    String prompt,
    TextAgentExpectLatency latency,
  ) async {
    _logService.info(
      _tag,
      'Validating async query for agent: ${agent.name}, latency: ${latency.value}',
    );

    // Validate prompt is not empty
    if (prompt.trim().isEmpty) {
      throw ArgumentError('Prompt cannot be empty');
    }

    // Generate a job token
    final token = _generateJobToken();

    _logService.info(
      _tag,
      'Async query validation passed, token: $token',
    );

    return token;
  }

  /// Poll for async job result by executing the query
  ///
  /// Returns the result if successful, null if still processing
  /// Throws [Exception] if the query fails
  Future<String?> pollAsyncResult(
    TextAgent agent,
    String prompt,
    TextAgentExpectLatency latency,
  ) async {
    _logService.debug(
      _tag,
      'Polling async result for agent: ${agent.name}',
    );

    final timeout = _getTimeoutForLatency(latency);

    try {
      final response = await _sendHttpRequest(
        agent,
        prompt,
        timeout: timeout,
      );

      _logService.info(
        _tag,
        'Async query completed for agent: ${agent.name}',
      );

      return response;
    } catch (e) {
      _logService.error(_tag, 'Async query failed: $e');
      rethrow;
    }
  }

  /// Execute HTTP request to OpenAI-compatible Chat Completions API
  Future<String> _sendHttpRequest(
    TextAgent agent,
    String prompt, {
    required Duration timeout,
  }) async {
    final config = agent.config;

    // Build the endpoint URL based on provider
    final url = Uri.parse(config.getEndpointUrl());
    final model = config.getModelIdentifier();
    final headers = config.getRequestHeaders();

    _logService.debug(
      _tag,
      'Provider: ${config.provider.displayName}, Model: $model, URL: $url',
    );

    // Build request body
    final requestBody = {
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'max_tokens': 4096,
      'temperature': 1.0,
    };

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

      if (response.statusCode != 200) {
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

  /// Generate a unique job token
  String _generateJobToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return 'job_${timestamp}_$random';
  }

  /// Get timeout duration based on latency tier
  Duration _getTimeoutForLatency(TextAgentExpectLatency latency) {
    switch (latency) {
      case TextAgentExpectLatency.instant:
        return const Duration(seconds: 30);
      case TextAgentExpectLatency.long:
        return const Duration(minutes: 10);
      case TextAgentExpectLatency.ultraLong:
        return const Duration(minutes: 60);
    }
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
