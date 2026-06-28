import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/repositories/api_speed_dial_repository.dart';

void main() {
  group('ApiSpeedDialRepository voiceAgentId mapping', () {
    test('maps voiceAgentId from API responses', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, [
          {
            'id': 'custom',
            'name': 'Custom',
            'systemPrompt': 'You are custom.',
            'voice': 'alloy',
            'voiceAgentId': 'voice-agent-prod-cc',
            'enabledTools': <String, bool>{},
            'reasoningEffort': 'off',
            'toolChoiceRequired': false,
          },
        ]);
      });
      final repository = ApiSpeedDialRepository(apiClient: _client(adapter));

      final speedDials = await repository.getAll();

      expect(speedDials.single.voiceAgentId, 'voice-agent-prod-cc');
    });

    test('sends voiceAgentId when saving', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, {
          'id': 'custom',
          'name': 'Custom',
          'systemPrompt': 'You are custom.',
          'voice': 'alloy',
          'voiceAgentId': 'voice-agent-prod-cc',
          'enabledTools': <String, bool>{},
          'reasoningEffort': 'off',
          'toolChoiceRequired': false,
        });
      });
      final repository = ApiSpeedDialRepository(apiClient: _client(adapter));

      await repository.save(
        const SpeedDial(
          id: 'custom',
          name: 'Custom',
          systemPrompt: 'You are custom.',
          voice: 'alloy',
          voiceAgentId: 'voice-agent-prod-cc',
        ),
      );

      expect(adapter.requests, hasLength(1));
      expect(adapter.requestBodies, hasLength(1));
      final body = jsonDecode(adapter.requestBodies.single) as Map<String, dynamic>;
      expect(body['voiceAgentId'], 'voice-agent-prod-cc');
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
  final List<String> requestBodies = <String>[];

  _RecordingAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bodyBytes = <int>[];
      await for (final chunk in requestStream) {
        bodyBytes.addAll(chunk);
      }
      if (bodyBytes.isNotEmpty) {
        requestBodies.add(utf8.decode(bodyBytes));
      }
    }
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
