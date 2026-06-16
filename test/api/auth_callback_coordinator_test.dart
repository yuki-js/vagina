import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/auth_callback_coordinator.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/api/generated/models/auth_token_response.dart';
import 'package:vagina/api/generated/models/exchange_oidc_login_body.dart';
import 'package:vagina/api/generated/models/user.dart';
import 'package:vagina/api/generated/models/user_account_lifecycle.dart';
import 'package:vagina/api/generated/responses/exchange_oidc_login_response.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/repositories/preferences_repository.dart';

void main() {
  group('AuthCallbackCoordinator', () {
    late InMemoryStore store;
    late PreferencesRepository preferences;

    setUp(() async {
      store = InMemoryStore();
      await store.initialize();
      preferences = PreferencesRepository(store);
    });

    test(
      'web callback exchanges on expected path and clears query params',
      () async {
        var didClearWebQuery = false;
        ExchangeOidcLoginBody? capturedBody;

        final authService = AuthService(
          preferencesRepository: preferences,
          exchangeOidcLoginCall: (_, body) async {
            capturedBody = body;
            return ExchangeOidcLoginResponse.success(
              _tokenResponse(
                accessToken: 'access-from-web-callback',
                refreshToken: 'refresh-from-web-callback',
              ),
            );
          },
        );
        final coordinator = AuthCallbackCoordinator(
          authService: authService,
          isWeb: true,
          isMobile: false,
          webBaseUriProvider: () =>
              Uri.parse('https://vagina.app/callback?code=code1&state=state1'),
          clearWebTransientParams: () {
            didClearWebQuery = true;
          },
        );
        addTearDown(coordinator.dispose);

        final events = <AuthCallbackEvent>[];
        final subscription = coordinator.events.listen(events.add);
        addTearDown(subscription.cancel);

        await preferences.savePendingPkceVerifier('verifier-web-1');
        await preferences.savePendingOidcProvider('github');
        await coordinator.start();
        await Future<void>.delayed(Duration.zero);

        expect(didClearWebQuery, isTrue);
        expect(capturedBody, isNotNull);
        expect(capturedBody!.code, 'code1');
        expect(capturedBody!.state, 'state1');
        expect(capturedBody!.codeVerifier, 'verifier-web-1');
        expect(events, hasLength(1));
        expect(events.single.isSuccess, isTrue);
        expect(
          await preferences.getAuthRefreshToken(),
          'refresh-from-web-callback',
        );
      },
    );

    test(
      'web callback accepts localhost:3000 callback in debug mode',
      () async {
        var didClearWebQuery = false;
        ExchangeOidcLoginBody? capturedBody;

        final authService = AuthService(
          preferencesRepository: preferences,
          exchangeOidcLoginCall: (_, body) async {
            capturedBody = body;
            return ExchangeOidcLoginResponse.success(
              _tokenResponse(
                accessToken: 'access-from-localhost-callback',
                refreshToken: 'refresh-from-localhost-callback',
              ),
            );
          },
        );
        final coordinator = AuthCallbackCoordinator(
          authService: authService,
          isWeb: true,
          isMobile: false,
          webBaseUriProvider: () => Uri.parse(
            'http://localhost:3000/callback?code=code-local&state=state-local',
          ),
          clearWebTransientParams: () {
            didClearWebQuery = true;
          },
        );
        addTearDown(coordinator.dispose);

        final events = <AuthCallbackEvent>[];
        final subscription = coordinator.events.listen(events.add);
        addTearDown(subscription.cancel);

        await preferences.savePendingPkceVerifier('verifier-local-1');
        await preferences.savePendingOidcProvider('github');
        await coordinator.start();
        await Future<void>.delayed(Duration.zero);

        expect(didClearWebQuery, isTrue);
        expect(capturedBody, isNotNull);
        expect(capturedBody!.code, 'code-local');
        expect(capturedBody!.state, 'state-local');
        expect(capturedBody!.codeVerifier, 'verifier-local-1');
        expect(events, hasLength(1));
        expect(events.single.isSuccess, isTrue);
        expect(
          await preferences.getAuthRefreshToken(),
          'refresh-from-localhost-callback',
        );
      },
    );

    test(
      'web callback ignores non-callback path even if query shape matches',
      () async {
        var didClearWebQuery = false;
        var exchangeCallCount = 0;

        final authService = AuthService(
          preferencesRepository: preferences,
          exchangeOidcLoginCall: (_, _) async {
            exchangeCallCount++;
            return ExchangeOidcLoginResponse.success(
              _tokenResponse(accessToken: 'access', refreshToken: 'refresh'),
            );
          },
        );
        final coordinator = AuthCallbackCoordinator(
          authService: authService,
          isWeb: true,
          isMobile: false,
          webBaseUriProvider: () => Uri.parse(
            'https://vagina.app/not-callback?code=code2&state=state2',
          ),
          clearWebTransientParams: () {
            didClearWebQuery = true;
          },
        );
        addTearDown(coordinator.dispose);

        final events = <AuthCallbackEvent>[];
        final subscription = coordinator.events.listen(events.add);
        addTearDown(subscription.cancel);

        await preferences.savePendingPkceVerifier('verifier-mobile-1');
        await preferences.savePendingOidcProvider('github');
        await coordinator.start();
        await Future<void>.delayed(Duration.zero);

        expect(exchangeCallCount, 0);
        expect(didClearWebQuery, isFalse);
        expect(events, isEmpty);
        expect(await preferences.getAuthRefreshToken(), isNull);
      },
    );

    test('provider error callback emits failure with reason', () async {
      final authService = AuthService(preferencesRepository: preferences);
      final coordinator = AuthCallbackCoordinator(
        authService: authService,
        isWeb: true,
        isMobile: false,
        webBaseUriProvider: () => Uri.parse(
          'https://vagina.app/callback?error=access_denied&error_description=user%20cancelled',
        ),
        clearWebTransientParams: () {},
      );
      addTearDown(coordinator.dispose);

      final events = <AuthCallbackEvent>[];
      final subscription = coordinator.events.listen(events.add);
      addTearDown(subscription.cancel);

      await coordinator.start();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.isSuccess, isFalse);
      expect(
        events.single.failureReason,
        AuthCallbackFailureReason.providerError,
      );
      expect(events.single.detail, contains('access_denied'));
    });

    test('mobile callback deduplicates by state', () async {
      final uriController = StreamController<Uri>.broadcast();
      var exchangeCallCount = 0;

      final authService = AuthService(
        preferencesRepository: preferences,
        exchangeOidcLoginCall: (_, body) async {
          exchangeCallCount++;
          return ExchangeOidcLoginResponse.success(
            _tokenResponse(
              accessToken: 'access-${body.state}',
              refreshToken: 'refresh-${body.state}',
            ),
          );
        },
      );
      final coordinator = AuthCallbackCoordinator(
        authService: authService,
        isWeb: false,
        isMobile: true,
        mobileInitialLinkProvider: () async => null,
        mobileUriStreamProvider: () => uriController.stream,
      );
      addTearDown(() async {
        await uriController.close();
        await coordinator.dispose();
      });

      final events = <AuthCallbackEvent>[];
      final subscription = coordinator.events.listen(events.add);
      addTearDown(subscription.cancel);

      await coordinator.start();
      await preferences.savePendingPkceVerifier('verifier-mobile-1');
      await preferences.savePendingOidcProvider('github');

      uriController.add(
        Uri.parse('https://vagina.app/callback?code=code3&state=state3'),
      );
      uriController.add(
        Uri.parse('https://vagina.app/callback?code=code3b&state=state3'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(exchangeCallCount, 1);
      expect(events.where((event) => event.isSuccess).length, 1);
      expect(await preferences.getAuthRefreshToken(), 'refresh-state3');
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
      id: 'user-1',
      accountLifecycle: UserAccountLifecycle.active,
      displayName: 'Alice',
      avatarUrl: null,
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
    ),
  );
}
