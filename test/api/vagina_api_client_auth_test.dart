import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/api_exception.dart';
import 'package:vagina/api/auth_exception.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/repositories/api_speed_dial_repository.dart';

void main() {
  group('VaginaApiClient auth pipeline', () {
    test('protected request fails locally when token is unavailable', () async {
      final adapter = _RecordingAdapter((_) async {
        return _jsonResponse(200, <Object?>[]);
      });
      final client = _client(
        adapter: adapter,
        getAccessToken: ({bool forceRefresh = false}) async {
          throw const AuthException.authRequired();
        },
      );
      final repository = ApiSpeedDialRepository(apiClient: client);

      await expectLater(repository.getAll(), throwsA(isA<DioException>()));
      expect(adapter.requests, isEmpty);
    });

    test('protected request refreshes and retries once after a 401', () async {
      var tokenRequestCount = 0;
      final adapter = _RecordingAdapter((request) async {
        if (request.headers['Authorization'] == 'Bearer expired-access-token') {
          return _jsonResponse(401, <String, Object?>{
            'message': 'Invalid JWT token',
          });
        }
        return _jsonResponse(200, <Object?>[]);
      });
      final client = _client(
        adapter: adapter,
        getAccessToken: ({bool forceRefresh = false}) async {
          tokenRequestCount += 1;
          return forceRefresh ? 'fresh-access-token' : 'expired-access-token';
        },
      );
      final repository = ApiSpeedDialRepository(apiClient: client);

      await expectLater(repository.getAll(), completes);

      expect(tokenRequestCount, 2);
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.headers['Authorization'],
        'Bearer expired-access-token',
      );
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer fresh-access-token',
      );
    });

    test(
      'protected request signs out when forced refresh cannot recover',
      () async {
        var signOutCount = 0;
        final adapter = _RecordingAdapter((_) async {
          return _jsonResponse(401, <String, Object?>{
            'message': 'Invalid JWT token',
          });
        });
        final client = _client(
          adapter: adapter,
          getAccessToken: ({bool forceRefresh = false}) async {
            if (forceRefresh) {
              throw const AuthException.authRequired();
            }
            return 'expired-access-token';
          },
          onAuthenticationFailure: () async {
            signOutCount += 1;
          },
        );
        final repository = ApiSpeedDialRepository(apiClient: client);

        await expectLater(repository.getAll(), throwsA(isA<DioException>()));

        expect(adapter.requests, hasLength(1));
        expect(signOutCount, 1);
      },
    );

    test(
      'protected request signs out when retry is still unauthorized',
      () async {
        var signOutCount = 0;
        final adapter = _RecordingAdapter((_) async {
          return _jsonResponse(401, <String, Object?>{
            'message': 'Invalid JWT token',
          });
        });
        final client = _client(
          adapter: adapter,
          getAccessToken: ({bool forceRefresh = false}) async {
            return forceRefresh ? 'fresh-but-rejected-token' : 'expired-token';
          },
          onAuthenticationFailure: () async {
            signOutCount += 1;
          },
        );
        final repository = ApiSpeedDialRepository(apiClient: client);

        await expectLater(repository.getAll(), throwsA(isA<ApiException>()));

        expect(adapter.requests, hasLength(2));
        expect(signOutCount, 1);
      },
    );
  });
}

VaginaApiClient _client({
  required HttpClientAdapter adapter,
  required AuthTokenSupplier getAccessToken,
  Future<void> Function()? onAuthenticationFailure,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return VaginaApiClient(
    dioOverride: dio,
    getAccessToken: getAccessToken,
    onAuthenticationFailure: onAuthenticationFailure,
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
