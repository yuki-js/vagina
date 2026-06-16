import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/api/generated/responses/list_speed_dials_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/models/virtual_file.dart';
import 'package:vagina/repositories/api_speed_dial_repository.dart';
import 'package:vagina/repositories/api_virtual_filesystem_repository.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  group('Authenticated API flow', () {
    late InMemoryStore store;
    late PreferencesRepository preferences;

    setUp(() async {
      store = InMemoryStore();
      await store.initialize();
      preferences = PreferencesRepository(store);
    });

    test(
      'user can sign in and then use Speed Dial + VFS through API repositories',
      () async {
        final adapter = _ScriptedAdapter((options, callIndex) async {
          switch (callIndex) {
            case 0:
              expect(options.path, '/auth/oidc/github/exchange');
              expect(options.headers['Authorization'], isNull);
              return _jsonResponse(
                _authTokenResponse(
                  accessToken: 'access-token-1',
                  refreshToken: 'refresh-token-1',
                ),
                200,
              );
            case 1:
              expect(options.method, 'PUT');
              expect(options.path, '/speed-dials/custom-ops');
              expect(options.headers['Authorization'], 'Bearer access-token-1');
              return _jsonResponse({
                'id': 'custom-ops',
                'name': 'Ops',
                'systemPrompt': 'Be concise',
                'voice': 'alloy',
                'enabledTools': {
                  'document_read': true,
                  'document_patch': false,
                },
              }, 200);
            case 2:
              expect(options.method, 'GET');
              expect(options.path, '/speed-dials');
              expect(options.headers['Authorization'], 'Bearer access-token-1');
              return _jsonResponse([
                {
                  'id': 'custom-ops',
                  'name': 'Ops',
                  'systemPrompt': 'Be concise',
                  'voice': 'alloy',
                  'enabledTools': {
                    'document_read': true,
                    'document_patch': false,
                  },
                },
              ], 200);
            case 3:
              expect(options.path, '/vfs/rpc');
              expect(options.headers['Authorization'], 'Bearer access-token-1');
              expect(
                (options.data as Map<String, dynamic>)['method'],
                'vfs.write',
              );
              return _jsonResponse({
                'jsonrpc': '2.0',
                'id': 'req-1',
                'result': {
                  'file': {'path': '/notes/today.md', 'content': '# Today'},
                },
              }, 200);
            case 4:
              expect(options.path, '/vfs/rpc');
              expect(options.headers['Authorization'], 'Bearer access-token-1');
              expect(
                (options.data as Map<String, dynamic>)['method'],
                'vfs.read',
              );
              return _jsonResponse({
                'jsonrpc': '2.0',
                'id': 'req-2',
                'result': {
                  'file': {'path': '/notes/today.md', 'content': '# Today'},
                },
              }, 200);
            default:
              fail(
                'Unexpected call #$callIndex ${options.method} ${options.path}',
              );
          }
        });

        final authService = _buildAuthService(
          preferences: preferences,
          adapter: adapter,
        );
        final speedDialRepository = ApiSpeedDialRepository(
          apiClient: authService.apiClient,
        );
        final filesystemRepository = ApiVirtualFilesystemRepository(
          apiClient: authService.apiClient,
        );

        await preferences.savePendingPkceVerifier('verifier-1');
        await preferences.savePendingOidcProvider('github');
        await authService.exchangeOidcLogin(code: 'code-1', state: 'state-1');

        await speedDialRepository.save(
          const SpeedDial(
            id: 'custom-ops',
            name: 'Ops',
            systemPrompt: 'Be concise',
            voice: 'alloy',
            enabledTools: {'document_read': true, 'document_patch': false},
          ),
        );

        final speedDials = await speedDialRepository.getAll();
        expect(speedDials, hasLength(1));
        expect(speedDials.single.id, 'custom-ops');

        await filesystemRepository.write(
          const VirtualFile(path: '/notes/today.md', content: '# Today'),
        );
        final file = await filesystemRepository.read('/notes/today.md');
        expect(file, isNotNull);
        expect(file!.content, '# Today');
      },
    );

    test(
      'refresh revocation signs user out when protected call can no longer recover',
      () async {
        var signedOutCount = 0;
        final adapter = _ScriptedAdapter((options, callIndex) async {
          switch (callIndex) {
            case 0:
              expect(options.path, '/auth/oidc/github/exchange');
              return _jsonResponse(
                _authTokenResponse(
                  accessToken: 'stale-access',
                  refreshToken: 'refresh-token-1',
                ),
                200,
              );
            case 1:
              expect(options.path, '/speed-dials');
              expect(options.headers['Authorization'], 'Bearer stale-access');
              return _jsonResponse({'message': 'expired'}, 401);
            case 2:
              expect(options.path, '/auth/refresh');
              expect(options.headers['Authorization'], isNull);
              return _jsonResponse({'message': 'refresh revoked'}, 401);
            default:
              fail(
                'Unexpected call #$callIndex ${options.method} ${options.path}',
              );
          }
        });

        final authService = _buildAuthService(
          preferences: preferences,
          adapter: adapter,
        )..onSignedOut = () => signedOutCount++;

        await preferences.savePendingPkceVerifier('verifier-2');
        await preferences.savePendingOidcProvider('github');
        await authService.exchangeOidcLogin(code: 'code-2', state: 'state-2');

        final response = await authService.apiClient.speedDials
            .listSpeedDials();

        expect(response, isA<ListSpeedDialsResponseUnknown>());
        expect((response as ListSpeedDialsResponseUnknown).statusCode, 401);
        expect(await preferences.getAuthRefreshToken(), isNull);
        expect(signedOutCount, 1);
      },
    );
  });
}

AuthService _buildAuthService({
  required PreferencesRepository preferences,
  required HttpClientAdapter adapter,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api'));
  dio.httpClientAdapter = adapter;

  return AuthService(
    preferencesRepository: preferences,
    apiClientFactory: (accessTokenProvider, onUnauthorizedRefresh) {
      return VaginaApiClient(
        dioOverride: dio,
        accessTokenProvider: accessTokenProvider,
        onUnauthorizedRefresh: onUnauthorizedRefresh,
      );
    },
  );
}

Map<String, dynamic> _authTokenResponse({
  required String accessToken,
  required String refreshToken,
}) {
  return {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': 'Bearer',
    'expiresIn': 3600,
    'user': {
      'id': 'user-1',
      'accountLifecycle': 'active',
      'displayName': 'Alice',
      'avatarUrl': null,
      'createdAt': '2026-01-01T00:00:00Z',
    },
  };
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
  final Future<ResponseBody> Function(RequestOptions options, int callIndex)
  _handler;
  int _callCount = 0;

  _ScriptedAdapter(this._handler);

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
