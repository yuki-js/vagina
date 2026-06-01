import 'dart:async';
import 'package:vagina/feat/call/services/realtime/oai_cc/oai_cc_client.dart';
import 'package:vagina/feat/call/services/realtime/oai_cc/oai_cc_connect_config.dart';
import 'package:vagina/feat/call/services/realtime/oai_cc/oai_cc_request.dart';
import 'package:vagina/feat/call/services/realtime/oai_cc/oai_cc_event.dart';

/// Test Chat Completions API connectivity.
///
/// This helper mimics [OaiCcRealtimeAdapter] configuration resolution
/// and performs a minimal completions check to verify endpoint and API key.
Future<void> testCcConnection(
  String chatCompletionsUrl,
  String apiKey,
) async {
  final parsedUri = Uri.parse(chatCompletionsUrl);
  if (parsedUri.scheme.isEmpty || parsedUri.host.isEmpty) {
    throw Exception('Invalid Chat Completions base URI');
  }

  String extractedModel = 'gpt-4o';
  Uri cleanUri = parsedUri;

  if (parsedUri.queryParameters.containsKey('model')) {
    final modelFromQuery = parsedUri.queryParameters['model'];
    if (modelFromQuery != null && modelFromQuery.isNotEmpty) {
      extractedModel = modelFromQuery;
    }
    final newQueryParameters =
        Map<String, String>.from(parsedUri.queryParameters)..remove('model');
    cleanUri = parsedUri.replace(
      queryParameters: newQueryParameters.isEmpty ? null : newQueryParameters,
    );
  }

  final isAudioModel = extractedModel.toLowerCase().contains('audio') ||
                       extractedModel.toLowerCase().contains('gpt-5.4') ||
                       extractedModel.toLowerCase().contains('realtime');

  final config = OaiCcConnectConfig(
    baseUrl: cleanUri,
    model: extractedModel,
    apiKey: apiKey,
  );

  final request = OaiCcRequest(
    model: extractedModel,
    messages: [
      const OaiCcTextMessage(role: 'user', content: 'ping'),
    ],
    stream: true,
    modalities: isAudioModel ? ['text', 'audio'] : null,
    additionalParams: isAudioModel
        ? {
            'audio': {
              'voice': 'alloy',
              'format': 'pcm16',
            }
          }
        : null,
  );

  final client = OaiCcClient();
  final completer = Completer<void>();
  StreamSubscription<OaiCcEvent>? sub;

  try {
    final eventStream = client.streamCompletions(
      config: config,
      requestPayload: request,
    );

    sub = eventStream.listen(
      (event) {
        if (event is OaiCcErrorEvent) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(event.message));
          }
        } else {
          // If we receive any successful delta/finished event, connection is verified.
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      },
      onError: (err) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(err.toString()));
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Connection timeout');
      },
    );
  } finally {
    await sub?.cancel();
    client.dispose();
  }
}
