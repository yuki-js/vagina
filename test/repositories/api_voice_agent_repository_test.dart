import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/api_exception.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/repositories/api_voice_agent_repository.dart';

void main() {
  group('ApiVoiceAgentRepository', () {
    test(
      'maps server registry voice agents without provider details',
      () async {
        final adapter = _RecordingAdapter((_) async {
          return _jsonResponse(200, [
            {
              'id': 'voice-agent-prod',
              'displayName': 'Production',
              'isDefault': true,
            },
            {
              'id': 'voice-agent-prod-cc',
              'displayName': 'Production CC',
              'isDefault': false,
            },
          ]);
        });
        final repository = ApiVoiceAgentRepository(apiClient: _client(adapter));

        final voiceAgents = await repository.listVoiceAgents();

        expect(adapter.requests.single.path, '/voice-agents');
        expect(voiceAgents, hasLength(2));
        expect(voiceAgents.first.id, 'voice-agent-prod');
        expect(voiceAgents.first.displayName, 'Production');
        expect(voiceAgents.first.isDefault, isTrue);
        expect(voiceAgents.last.id, 'voice-agent-prod-cc');
        expect(voiceAgents.last.isDefault, isFalse);
      },
    );

    test('throws ApiException on server errors', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(500, {'message': 'registry unavailable'});
      });
      final repository = ApiVoiceAgentRepository(apiClient: _client(adapter));

      await expectLater(
        repository.listVoiceAgents(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.type, 'type', ApiErrorType.serverError)
              .having(
                (error) => error.message,
                'message',
                'registry unavailable',
              )
              .having(
                (error) => error.operation,
                'operation',
                'List voice agents',
              ),
        ),
      );
    });
  });
}

VaginaApiClient _client(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return VaginaApiClient(
    dioOverride: dio,
    getAccessToken: ({bool forceRefresh = false}) async => 'test-token',
  );
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

final class _RecordingAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions request) _handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  _RecordingAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
