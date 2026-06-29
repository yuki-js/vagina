import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/api/generated/models/auth_token_response.dart';
import 'package:vagina/api/generated/models/error_response.dart';
import 'package:vagina/api/generated/models/user.dart';
import 'package:vagina/api/generated/models/user_account_lifecycle.dart';
import 'package:vagina/api/generated/responses/logout_response.dart';
import 'package:vagina/api/generated/responses/refresh_session_response.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  group('AuthService', () {
    test(
      'getAccessToken returns refreshed token and enters authenticated state',
      () async {
        final store = _MemoryKeyValueStore();
        final preferences = PreferencesRepository(store);
        await preferences.saveAuthRefreshToken('refresh-token');
        final authService = AuthService(
          preferencesRepository: preferences,
          refreshSessionCall: (_) async => RefreshSessionResponse.success(
            _tokenResponse(accessToken: 'access-token'),
          ),
        );

        final token = await authService.getAccessToken();

        expect(token, 'access-token');
        expect(authService.authState, AuthState.authenticated);
      },
    );

    test(
      'getAccessToken enters signed-out state when refresh token is missing',
      () async {
        final authService = AuthService(
          preferencesRepository: PreferencesRepository(_MemoryKeyValueStore()),
        );
        var notificationCount = 0;
        authService.addListener(() {
          notificationCount += 1;
        });

        await expectLater(
          authService.getAccessToken(),
          throwsA(
            isA<AuthException>().having(
              (error) => error.code,
              'code',
              AuthException.authRequiredCode,
            ),
          ),
        );

        expect(authService.authState, AuthState.signedOut);
        expect(notificationCount, 0);
      },
    );

    test(
      'getAccessToken enters signed-out state when refresh token is invalid',
      () async {
        final store = _MemoryKeyValueStore();
        final preferences = PreferencesRepository(store);
        await preferences.saveAuthRefreshToken('invalid-refresh-token');
        final authService = AuthService(
          preferencesRepository: preferences,
          refreshSessionCall: (_) async =>
              const RefreshSessionResponse.unauthorized(
                ErrorResponse(message: 'Invalid refresh token'),
              ),
        );

        await expectLater(
          authService.getAccessToken(),
          throwsA(isA<AuthException>()),
        );

        expect(authService.authState, AuthState.signedOut);
        expect(await preferences.getAuthRefreshToken(), isNull);
      },
    );

    test(
      'getAccessToken shares one refresh call across concurrent callers',
      () async {
        final store = _MemoryKeyValueStore();
        final preferences = PreferencesRepository(store);
        await preferences.saveAuthRefreshToken('refresh-token');
        var refreshCount = 0;
        final authService = AuthService(
          preferencesRepository: preferences,
          refreshSessionCall: (_) async {
            refreshCount += 1;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return RefreshSessionResponse.success(
              _tokenResponse(accessToken: 'shared-access-token'),
            );
          },
        );

        final tokens = await Future.wait(<Future<String>>[
          authService.getAccessToken(),
          authService.getAccessToken(),
        ]);

        expect(tokens, <String>['shared-access-token', 'shared-access-token']);
        expect(refreshCount, 1);
        expect(authService.authState, AuthState.authenticated);
      },
    );

    test('logout revokes refresh token and clears local session', () async {
      final store = _MemoryKeyValueStore();
      final preferences = PreferencesRepository(store);
      await preferences.saveAuthRefreshToken('refresh-token');
      var revokedRefreshToken = '';
      final authService = AuthService(
        preferencesRepository: preferences,
        logoutCall: (body) async {
          revokedRefreshToken = body.refreshToken;
          return const LogoutResponse.noContent();
        },
      );

      await authService.logout();

      expect(revokedRefreshToken, 'refresh-token');
      expect(await preferences.getAuthRefreshToken(), isNull);
      expect(authService.authState, AuthState.signedOut);
    });

    test('logout clears local session when server revocation fails', () async {
      final store = _MemoryKeyValueStore();
      final preferences = PreferencesRepository(store);
      await preferences.saveAuthRefreshToken('refresh-token');
      final authService = AuthService(
        preferencesRepository: preferences,
        logoutCall: (_) async => const LogoutResponse.unknown(500, null),
      );

      await authService.logout();

      expect(await preferences.getAuthRefreshToken(), isNull);
      expect(authService.authState, AuthState.signedOut);
    });

    test('logout succeeds locally when refresh token is missing', () async {
      final preferences = PreferencesRepository(_MemoryKeyValueStore());
      final authService = AuthService(preferencesRepository: preferences);

      await authService.logout();

      expect(await preferences.getAuthRefreshToken(), isNull);
      expect(authService.authState, AuthState.signedOut);
    });
  });
}

AuthTokenResponse _tokenResponse({required String accessToken}) {
  return AuthTokenResponse(
    accessToken: accessToken,
    refreshToken: 'next-refresh-token',
    tokenType: 'Bearer',
    expiresIn: 3600,
    user: User(
      id: 'user-1',
      accountLifecycle: UserAccountLifecycle.active,
      createdAt: DateTime.utc(2024),
    ),
  );
}

final class _MemoryKeyValueStore implements KeyValueStore {
  final Map<String, dynamic> _data = <String, dynamic>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, dynamic>> load() async => Map<String, dynamic>.from(_data);

  @override
  Future<void> save(Map<String, dynamic> data) async {
    _data
      ..clear()
      ..addAll(data);
  }

  @override
  Future<dynamic> get(String key) async => _data[key];

  @override
  Future<void> set(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<bool> contains(String key) async => _data.containsKey(key);

  @override
  Future<void> clear() async {
    _data.clear();
  }

  @override
  Future<String> getFilePath() async => 'memory://auth-service-test';
}
