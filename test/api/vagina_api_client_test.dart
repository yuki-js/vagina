import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/generated/responses/list_speed_dials_response.dart';
import 'package:vagina/api/vagina_api_client.dart';

void main() {
  /// User-centric scenarios for the client auth lifecycle around protected API calls.
  ///
  /// Why these tests exist:
  /// - Real users keep the app open for long periods; access tokens naturally expire.
  /// - The first action after returning to the app is often opening authenticated tabs
  ///   (for example, Speed Dial list fetch).
  /// - The app must transparently recover with a single refresh+retry, or fail fast
  ///   without retry loops when refresh cannot recover the session.
  group('VaginaApiClient auth retry', () {
    test(
      'expired access token should refresh once and retry protected request',
      () async {
        // Scenario:
        // 1. User opens the app and requests Speed Dial list.
        // 2. Existing access token is expired.
        // 3. Server returns 401 on the first protected request.
        // 4. Client refreshes once via RT and retries the same request.
        // 5. Retry succeeds and the user gets data without manual re-login.
        var token = 'expired-token';
        var refreshCallCount = 0;

        final adapter = _ScriptedAdapter((options, callIndex) async {
          if (callIndex == 0) {
            expect(options.path, '/speed-dials');
            expect(options.headers['Authorization'], 'Bearer expired-token');
            return _jsonResponse({'message': 'expired'}, 401);
          }

          expect(options.path, '/speed-dials');
          expect(options.headers['Authorization'], 'Bearer refreshed-token');
          return _jsonResponse([
            {
              'id': 'default',
              'name': 'Default',
              'systemPrompt': 'prompt',
              'voice': 'alloy',
              'enabledTools': {'document_read': true, 'document_patch': false},
            },
          ], 200);
        });

        final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api'));
        dio.httpClientAdapter = adapter;

        final apiClient = VaginaApiClient(
          dioOverride: dio,
          accessTokenProvider: () async => token,
          onUnauthorizedRefresh: () async {
            refreshCallCount++;
            token = 'refreshed-token';
            return token;
          },
        );

        final response = await apiClient.speedDials.listSpeedDials();

        expect(refreshCallCount, 1);
        expect(adapter.callCount, 2);
        expect(response, isA<ListSpeedDialsResponseSuccess>());
        final data = (response as ListSpeedDialsResponseSuccess).data;
        expect(data, hasLength(1));
        expect(data.single.enabledTools['document_read'], isTrue);
        expect(data.single.enabledTools['document_patch'], isFalse);
      },
    );

    test('refresh failure should not retry protected request', () async {
      // Scenario:
      // 1. User requests Speed Dial list with expired AT.
      // 2. First protected request gets 401.
      // 3. Refresh path cannot issue a new AT (e.g., RT revoked/expired).
      // 4. Client must stop retrying and surface unauthorized once.
      //
      // UX goal:
      // - Avoid silent infinite retries / hanging UI.
      // - Let upper layers transition to explicit sign-in recovery.
      var refreshCallCount = 0;

      final adapter = _ScriptedAdapter((options, callIndex) async {
        expect(callIndex, 0);
        expect(options.path, '/speed-dials');
        return _jsonResponse({'message': 'expired'}, 401);
      });

      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api'));
      dio.httpClientAdapter = adapter;

      final apiClient = VaginaApiClient(
        dioOverride: dio,
        accessTokenProvider: () async => 'expired-token',
        onUnauthorizedRefresh: () async {
          refreshCallCount++;
          return null;
        },
      );

      final response = await apiClient.speedDials.listSpeedDials();

      expect(refreshCallCount, 1);
      expect(adapter.callCount, 1);
      expect(response, isA<ListSpeedDialsResponseUnknown>());
      final unknown = response as ListSpeedDialsResponseUnknown;
      expect(unknown.statusCode, 401);
    });
  });
}

ResponseBody _jsonResponse(Object body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _ScriptedAdapter implements HttpClientAdapter {
  // Minimal deterministic adapter for scenario orchestration:
  // each fetch invocation advances callIndex so tests can model
  // "first call fails / second call succeeds" sequences.
  final Future<ResponseBody> Function(RequestOptions options, int callIndex)
  _handler;
  int _callCount = 0;

  _ScriptedAdapter(this._handler);

  int get callCount => _callCount;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final current = _callCount;
    _callCount++;
    return _handler(options, current);
  }
}
