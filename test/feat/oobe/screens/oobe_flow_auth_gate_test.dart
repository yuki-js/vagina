import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vagina/api/auth_callback_coordinator.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/api/generated/models/auth_token_response.dart';
import 'package:vagina/api/generated/models/error_response.dart';
import 'package:vagina/api/generated/models/refresh_session_body.dart';
import 'package:vagina/api/generated/models/user.dart';
import 'package:vagina/api/generated/models/user_account_lifecycle.dart';
import 'package:vagina/api/generated/responses/start_oidc_login_response.dart';
import 'package:vagina/api/generated/responses/get_current_user_response.dart';
import 'package:vagina/api/generated/responses/refresh_session_response.dart';
import 'package:vagina/core/data/in_memory_store.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/call/models/hosted_voice_agent_defaults.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/oobe/screens/oobe_flow.dart';
import 'package:vagina/l10n/app_localizations.dart';

void main() {
  /// OOBE scenario tests focus on user progression rules, not just widget rendering.
  ///
  /// Core product expectation:
  /// - First-launch users must complete GitHub sign-in before advancing into
  ///   setup steps that assume an authenticated API session.
  setUp(() async {
    AppContainer.reset();
    final store = InMemoryStore();
    await store.initialize();
    await AppContainer.initialize(store: store);
  });

  tearDown(() {
    AppContainer.reset();
  });

  testWidgets('user cannot continue to manual setup before GitHub sign-in', (
    tester,
  ) async {
    // Scenario:
    // 1. Fresh first-launch user enters OOBE.
    // 2. User reaches authentication page.
    // 3. Without completing GitHub sign-in, user taps "Set up manually".
    //
    // Expected behavior:
    // - Show explicit sign-in-required feedback.
    // - Keep user on authentication screen.
    // - Do not navigate into manual setup screen.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OobeFlowScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final context = tester.element(find.byType(OobeFlowScreen));
    final l10n = AppLocalizations.of(context);

    await tester.tap(find.text(l10n.welcomeTapToBegin));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(l10n.oobeAuthenticationTitle), findsOneWidget);

    await tester.tap(find.text(l10n.oobeAuthenticationManualSetup));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(l10n.oobeAuthenticationSignInRequired), findsOneWidget);
    expect(find.text(l10n.oobeManualSetupTitle), findsNothing);
    expect(find.text(l10n.oobeAuthenticationTitle), findsOneWidget);
  });

  testWidgets('unsupported provider shows explicit error feedback', (
    tester,
  ) async {
    final authService = AuthService(
      preferencesRepository: AppContainer.preferences,
      startOidcLoginCall: (provider, _) async {
        expect(provider, 'google');
        return const StartOidcLoginResponse.status501(
          ErrorResponse(message: 'Provider not implemented: google'),
        );
      },
    );

    AppContainer.setOverridesForTesting(
      authService: authService,
      authCallbacks: AuthCallbackCoordinator(
        authService: authService,
        isWeb: false,
        isMobile: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OobeFlowScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final context = tester.element(find.byType(OobeFlowScreen));
    final l10n = AppLocalizations.of(context);

    await tester.tap(find.text(l10n.welcomeTapToBegin));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(
      find.text(l10n.oobeAuthenticationProviderButton('Google')),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.textContaining('Provider not implemented: google'),
      findsOneWidget,
    );
    expect(find.text(l10n.oobeAuthenticationTitle), findsOneWidget);
  });

  testWidgets(
    'restored signed-in session skips welcome/auth/manual-setup and saves default hosted config',
    (tester) async {
      // Pre-condition: a refresh token exists from a prior session.
      await AppContainer.preferences.saveAuthRefreshToken(
        'refresh-before-launch',
      );
      final authService = AuthService(
        preferencesRepository: AppContainer.preferences,
        refreshSessionCall: (body) async {
          expect(
            body,
            const RefreshSessionBody(refreshToken: 'refresh-before-launch'),
          );
          return RefreshSessionResponse.success(
            AuthTokenResponse(
              accessToken: 'access-restored',
              refreshToken: 'refresh-rotated',
              tokenType: 'Bearer',
              expiresIn: 3600,
              user: User(
                id: 'u-1',
                accountLifecycle: UserAccountLifecycle.active,
                displayName: 'Alice',
                avatarUrl: null,
                createdAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
              ),
            ),
          );
        },
        getCurrentUserCall: () async => GetCurrentUserResponse.success(
          User(
            id: 'u-1',
            accountLifecycle: UserAccountLifecycle.active,
            displayName: 'Alice',
            avatarUrl: null,
            createdAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
          ),
        ),
      );

      AppContainer.setOverridesForTesting(
        authService: authService,
        authCallbacks: AuthCallbackCoordinator(
          authService: authService,
          isWeb: false,
          isMobile: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OobeFlowScreen(),
        ),
      );
      // Allow _syncSignInState() to run: the auth call, config-existence check,
      // and default-config save are all async. Pump once to kick off the futures,
      // then pump again to apply the resulting setState rebuild.
      await tester.pump();
      await tester.pump();

      // ── Core regression assertion ──────────────────────────────────────────
      // The hosted config MUST have been saved during the session-restore path
      // so that the call screen never throws:
      //   StateError('Voice agent API config is not configured.')
      //
      // This is the canonical check for the OOBE play-path blocker fix.
      final savedConfig = await AppContainer.config.getVoiceAgentApiConfig();
      expect(savedConfig, isA<HostedVoiceAgentApiConfig>());
      expect(
        (savedConfig as HostedVoiceAgentApiConfig).modelId,
        HostedVoiceAgentDefaults.defaultModelId,
      );
    },
  );
}
