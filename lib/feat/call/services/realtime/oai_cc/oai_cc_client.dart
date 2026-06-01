import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'oai_cc_connect_config.dart';
import 'oai_cc_event.dart';
import 'oai_cc_request.dart';

/// Client to communicate with OpenAI Chat Completions API.
final class OaiCcClient {
  final http.Client _client;
  final OaiCcEventParser _parser;

  /// The active request client if any request is currently streaming.
  http.Client? _activeClient;

  OaiCcClient({
    http.Client? client,
    OaiCcEventParser? parser,
  })  : _client = client ?? http.Client(),
        _parser = parser ?? const OaiCcEventParser();

  /// Send a chat completions request and yield streamed events.
  Stream<OaiCcEvent> streamCompletions({
    required OaiCcConnectConfig config,
    required OaiCcRequest requestPayload,
  }) async* {
    // Cancel any ongoing request before starting a new one
    cancelOngoingRequest();

    final requestClient = http.Client();
    _activeClient = requestClient;

    final url =
        config.baseUrl.replace(path: '${config.baseUrl.path}/chat/completions');
    final httpRequest = http.Request('POST', url);

    // Apply authorization header
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      httpRequest.headers['Authorization'] = 'Bearer ${config.apiKey}';
    }
    httpRequest.headers['Content-Type'] = 'application/json';

    // Apply extra headers (e.g. OpenAI organization/project if any)
    config.extraHeaders.forEach((key, value) {
      httpRequest.headers[key] = value;
    });

    httpRequest.body = jsonEncode(requestPayload.toJson());

    try {
      final response = await requestClient.send(httpRequest);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        yield OaiCcErrorEvent(
          message: 'API returned error status ${response.statusCode}: $body',
        );
        return;
      }

      // Read response stream line-by-line
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        final event = _parser.parseLine(line);
        if (event != null) {
          yield event;
        }
      }
    } catch (e) {
      yield OaiCcErrorEvent(message: 'Request failed: $e');
    } finally {
      if (_activeClient == requestClient) {
        _activeClient = null;
      }
      requestClient.close();
    }
  }

  /// Cancels any active connection / stream.
  void cancelOngoingRequest() {
    _activeClient?.close();
    _activeClient = null;
  }

  /// Closes the shared HTTP client resources.
  void dispose() {
    cancelOngoingRequest();
    _client.close();
  }
}
