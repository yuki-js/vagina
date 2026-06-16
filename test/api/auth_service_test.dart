import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/api/generated/models/auth_token_response.dart';
import 'package:vagina/api/generated/models/error_response.dart';
import 'package:vagina/api/generated/models/exchange_oidc_login_body.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body_code_challenge_method.dart';
import 'package:vagina/api/generated/models/start_oidc_login_success_body.dart';
import 'package:vagina/api/generated/models/user.dart';
import 'package:vagina/api/generated/models/user_account_lifecycle.dart';
import 'package:vagina/api/generated/responses/exchange_oidc_login_response.dart';
import 'package:vagina/api/generated/responses/refresh_session_response.dart';
import 'package:vagina/api/generated/responses/start_oidc_login_response.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  group('AuthService', () {
    late InMemoryStore store;
    late PreferencesRepository preferences;

    setUp(() async {
      store = InMemoryStore();
      await store.initialize();
      preferences = PreferencesRepository(store);
    });

    test('startOidcLogin should send PKCE challenge and return URL', () async {
      String? capturedProvider;
      StartOidcLoginBody? capturedBody;

      final service = AuthService(
        preferencesRepository: preferences,
        startOidcLoginCall: (provider, body) async {
          capturedProvider = provider;
          capturedBody = body;
          return const StartOidcLoginResponse.success(
            StartOidcLoginSuccessBody(
              authorizationUrl: 'https://github.com/login/oauth/authorize',
            ),
          );
        },
      );

      final authorizationUri = await service.startOidcLogin();

      expect(capturedProvider, 'github');
      expect(capturedBody, isNotNull);
      expect(capturedBody!.codeChallenge, isNotEmpty);
      expect(
        capturedBody!.codeChallengeMethod,
        StartOidcLoginBodyCodeChallengeMethod.s256,
      );
      expect(
        authorizationUri,
        Uri.parse('https://github.com/login/oauth/authorize'),
      );
    });

    test(
      'startOidcLogin should surface provider-not-implemented responses',
      () async {
        final service = AuthService(
          preferencesRepository: preferences,
          startOidcLoginCall: (provider, body) async {
            expect(provider, 'google');
            return const StartOidcLoginResponse.status501(
              ErrorResponse(message: 'Provider not implemented: google'),
            );
          },
        );

        expect(
          () => service.startOidcLogin(provider: 'google'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'Provider not implemented: google',
            ),
          ),
        );
      },
    );

    test(
      'exchangeOidcLogin should persist refresh token and expose access token',
      () async {
        ExchangeOidcLoginBody? capturedBody;

        final service = AuthService(
          preferencesRepository: preferences,
          exchangeOidcLoginCall: (provider, body) async {
            capturedBody = body;
            return ExchangeOidcLoginResponse.success(
              _tokenResponse(
                accessToken: 'access-from-exchange',
                refreshToken: 'refresh-from-exchange',
              ),
            );
          },
        );

        await preferences.savePendingPkceVerifier('verifier-1');
        await preferences.savePendingOidcProvider('github');
        await service.exchangeOidcLogin(code: 'code-1', state: 'state-1');
        final accessToken = await service.getAccessToken();
        final refreshToken = await preferences.getAuthRefreshToken();

        expect(capturedBody, isNotNull);
        expect(capturedBody!.code, 'code-1');
        expect(capturedBody!.state, 'state-1');
        expect(capturedBody!.codeVerifier, 'verifier-1');
        expect(accessToken, 'access-from-exchange');
        expect(refreshToken, 'refresh-from-exchange');
      },
    );

    test(
      'getAccessToken should refresh only once under concurrent requests',
      () async {
        await preferences.saveAuthRefreshToken('refresh-old');

        int refreshCallCount = 0;
        final completer = Completer<void>();
        final service = AuthService(
          preferencesRepository: preferences,
          refreshSessionCall: (body) async {
            refreshCallCount++;
            expect(body.refreshToken, 'refresh-old');
            await completer.future;
            return RefreshSessionResponse.success(
              _tokenResponse(
                accessToken: 'access-refreshed',
                refreshToken: 'refresh-rotated',
              ),
            );
          },
        );

        final f1 = service.getAccessToken();
        final f2 = service.getAccessToken();

        completer.complete();

        final token1 = await f1;
        final token2 = await f2;
        final persistedRefresh = await preferences.getAuthRefreshToken();

        expect(refreshCallCount, 1);
        expect(token1, 'access-refreshed');
        expect(token2, 'access-refreshed');
        expect(persistedRefresh, 'refresh-rotated');
      },
    );

    test(
      'getAccessToken should clear persisted RT when refresh is unauthorized',
      () async {
        await preferences.saveAuthRefreshToken('refresh-old');

        final service = AuthService(
          preferencesRepository: preferences,
          refreshSessionCall: (_) async =>
              const RefreshSessionResponse.unauthorized(
                ErrorResponse(message: 'invalid refresh token'),
              ),
        );

        final token = await service.getAccessToken();
        final persistedRefresh = await preferences.getAuthRefreshToken();

        expect(token, isNull);
        expect(persistedRefresh, isNull);
      },
    );

    test('refresh unauthorized should emit signed-out notification', () async {
      await preferences.saveAuthRefreshToken('refresh-old');
      var signedOutCount = 0;

      final service = AuthService(
        preferencesRepository: preferences,
        refreshSessionCall: (_) async =>
            const RefreshSessionResponse.unauthorized(
              ErrorResponse(message: 'invalid refresh token'),
            ),
      )..onSignedOut = () => signedOutCount++;

      final token = await service.getAccessToken();

      expect(token, isNull);
      expect(signedOutCount, 1);
    });
  });
}

AuthTokenResponse _tokenResponse({
  required String accessToken,
  required String refreshToken,
}) {
  return AuthTokenResponse(
    accessToken: accessToken,
    refreshToken: refreshToken,
    tokenType: 'Bearer',
    expiresIn: 3600,
    user: User(
      id: '123',
      accountLifecycle: UserAccountLifecycle.active,
      displayName: 'Alice',
      avatarUrl: null,
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
    ),
  );
}
