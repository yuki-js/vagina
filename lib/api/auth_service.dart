import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:vagina/api/auth_exception.dart';
import 'package:vagina/api/generated/models/auth_token_response.dart';
import 'package:vagina/api/generated/models/exchange_oidc_login_body.dart';
import 'package:vagina/api/generated/models/logout_body.dart';
import 'package:vagina/api/generated/models/refresh_session_body.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body_client_type.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body_code_challenge_method.dart';
import 'package:vagina/api/generated/models/user.dart';
import 'package:vagina/api/generated/responses/exchange_oidc_login_response.dart';
import 'package:vagina/api/generated/responses/get_current_user_response.dart';
import 'package:vagina/api/generated/responses/logout_response.dart';
import 'package:vagina/api/generated/responses/refresh_session_response.dart';
import 'package:vagina/api/generated/responses/start_oidc_login_response.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/repositories/preferences_repository.dart';
import 'package:vagina/utils/platform_compat.dart';

export 'package:vagina/api/auth_exception.dart';

enum AuthState { signedOut, authenticated }

typedef AuthenticatedApiClientFactory =
    VaginaApiClient Function(
      AuthTokenSupplier getAccessToken,
      Future<void> Function() discardSession,
    );

class AuthService extends ChangeNotifier {
  static final String callbackUrl = AppConfig.callbackUrl;
  static const String defaultProvider = 'github';
  static const Duration accessTokenRefreshLeeway = Duration(seconds: 60);

  final PreferencesRepository _preferencesRepository;
  final Random _random;
  late final VaginaApiClient _apiClient;
  late final Future<StartOidcLoginResponse> Function(
    String provider,
    StartOidcLoginBody body,
  )
  _startOidcLoginCall;
  late final Future<ExchangeOidcLoginResponse> Function(
    String provider,
    ExchangeOidcLoginBody body,
  )
  _exchangeOidcLoginCall;
  late final Future<RefreshSessionResponse> Function(RefreshSessionBody body)
  _refreshSessionCall;
  late final Future<LogoutResponse> Function(LogoutBody body) _logoutCall;
  late final Future<GetCurrentUserResponse> Function() _getCurrentUserCall;

  String? _accessToken;
  String _tokenType = 'Bearer';
  DateTime? _accessTokenExpiresAtUtc;
  Future<_RefreshAttempt>? _refreshInFlight;
  AuthState _authState = AuthState.signedOut;

  AuthService({
    required PreferencesRepository preferencesRepository,
    Random? random,
    AuthenticatedApiClientFactory? apiClientFactory,
    Future<StartOidcLoginResponse> Function(
      String provider,
      StartOidcLoginBody body,
    )?
    startOidcLoginCall,
    Future<ExchangeOidcLoginResponse> Function(
      String provider,
      ExchangeOidcLoginBody body,
    )?
    exchangeOidcLoginCall,
    Future<RefreshSessionResponse> Function(RefreshSessionBody body)?
    refreshSessionCall,
    Future<LogoutResponse> Function(LogoutBody body)? logoutCall,
    Future<GetCurrentUserResponse> Function()? getCurrentUserCall,
  }) : _preferencesRepository = preferencesRepository,
       _random = random ?? Random.secure() {
    _apiClient = (apiClientFactory ?? _defaultApiClientFactory)(
      getAccessToken,
      discardSession,
    );
    _startOidcLoginCall =
        startOidcLoginCall ??
        (provider, body) =>
            _apiClient.auth.startOidcLogin(provider: provider, body: body);
    _exchangeOidcLoginCall =
        exchangeOidcLoginCall ??
        (provider, body) =>
            _apiClient.auth.exchangeOidcLogin(provider: provider, body: body);
    _refreshSessionCall =
        refreshSessionCall ??
        (body) => _apiClient.auth.refreshSession(body: body);
    _logoutCall = logoutCall ?? (body) => _apiClient.auth.logout(body: body);
    _getCurrentUserCall =
        getCurrentUserCall ?? () => _apiClient.auth.getCurrentUser();
  }

  static VaginaApiClient _defaultApiClientFactory(
    AuthTokenSupplier getAccessToken,
    Future<void> Function() discardSession,
  ) {
    return VaginaApiClient(
      getAccessToken: getAccessToken,
      onAuthenticationFailure: discardSession,
    );
  }

  VaginaApiClient get apiClient => _apiClient;

  AuthState get authState => _authState;

  String? get tokenType => _accessToken == null ? null : _tokenType;

  Future<Uri> startOidcLogin({String provider = defaultProvider}) async {
    final normalizedProvider = provider.trim();
    if (normalizedProvider.isEmpty) {
      throw const AuthException('OIDC provider is required.');
    }

    await _preferencesRepository.clearPendingPkceVerifier();
    await _preferencesRepository.clearPendingOidcProvider();
    final pkce = _issuePkcePair();
    final response = await _startOidcLoginCall(
      normalizedProvider,
      StartOidcLoginBody(
        clientType: _resolveClientType(),
        codeChallenge: pkce.codeChallenge,
        codeChallengeMethod: StartOidcLoginBodyCodeChallengeMethod.s256,
      ),
    );

    switch (response) {
      case StartOidcLoginResponseSuccess(:final data):
        await _preferencesRepository.savePendingPkceVerifier(pkce.codeVerifier);
        await _preferencesRepository.savePendingOidcProvider(
          normalizedProvider,
        );
        return Uri.parse(data.authorizationUrl);
      case StartOidcLoginResponseBadRequest(:final data):
        throw AuthException(data.message);
      case StartOidcLoginResponseStatus501(:final data):
        throw AuthException(data.message);
      case StartOidcLoginResponseBadGateway(:final data):
        throw AuthException(data.message);
      case StartOidcLoginResponseUnknown(:final statusCode):
        throw AuthException('Start OIDC login failed (status: $statusCode).');
    }
  }

  Future<void> exchangeOidcLogin({
    String? provider,
    required String code,
    required String state,
  }) async {
    final codeVerifier = await _preferencesRepository
        .consumePendingPkceVerifier();
    final pendingProvider = await _preferencesRepository
        .consumePendingOidcProvider();
    final effectiveProvider = (provider ?? pendingProvider ?? defaultProvider)
        .trim();
    if (effectiveProvider.isEmpty) {
      throw const AuthException('OIDC provider is required.');
    }
    if (codeVerifier == null) {
      await discardSession();
      throw const AuthException.authRequired();
    }

    final response = await _exchangeOidcLoginCall(
      effectiveProvider,
      ExchangeOidcLoginBody(
        code: code,
        state: state,
        codeVerifier: codeVerifier,
      ),
    );

    switch (response) {
      case ExchangeOidcLoginResponseSuccess(:final data):
        await _applyAuthTokenResponse(data);
      case ExchangeOidcLoginResponseBadRequest(:final data):
        throw AuthException(data.message);
      case ExchangeOidcLoginResponseUnauthorized(:final data):
        await discardSession();
        throw AuthException(data.message, code: AuthException.authRequiredCode);
      case ExchangeOidcLoginResponseStatus501(:final data):
        throw AuthException(data.message);
      case ExchangeOidcLoginResponseBadGateway(:final data):
        throw AuthException(data.message);
      case ExchangeOidcLoginResponseUnknown(:final statusCode, :final body):
        throw AuthException(
          _extractErrorMessage(
            body,
            fallback: 'Exchange OIDC login failed (status: $statusCode).',
          ),
        );
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      await getAccessToken();
    } on AuthException catch (error) {
      if (error.code == AuthException.authRequiredCode) {
        return null;
      }
      rethrow;
    }

    final response = await _getCurrentUserCall();
    return switch (response) {
      GetCurrentUserResponseSuccess(:final data) => data,
      GetCurrentUserResponseServerError(:final data) => throw AuthException(
        data.message,
      ),
      GetCurrentUserResponseUnknown(:final statusCode, :final body) =>
        throw AuthException(
          _extractErrorMessage(
            body,
            fallback: 'Get current user failed (status: $statusCode).',
          ),
        ),
    };
  }

  Future<void> logout() async {
    final refreshToken = await _preferencesRepository.getAuthRefreshToken();
    if (refreshToken != null) {
      try {
        await _logoutCall(LogoutBody(refreshToken: refreshToken));
      } catch (_) {
        // Server-side refresh token revocation is best-effort. The user intent
        // is to leave this device, so local session cleanup must always win.
      }
    }

    await discardSession();
  }

  Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasUsableCachedAccessToken()) {
      return _requireAccessToken(_accessToken);
    }

    final attempt = await _runRefreshSingleFlight();
    return switch (attempt) {
      _RefreshSuccess(:final accessToken) => _requireAccessToken(accessToken),
      _RefreshSignedOut() => throw const AuthException.authRequired(),
    };
  }

  Future<void> discardSession() async {
    await _preferencesRepository.clearAuthRefreshToken();
    await _preferencesRepository.clearPendingPkceVerifier();
    await _preferencesRepository.clearPendingOidcProvider();
    _clearAccessToken();
    _setAuthState(AuthState.signedOut);
  }

  Future<_RefreshAttempt> _runRefreshSingleFlight() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshAccessTokenWithRefreshToken();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<_RefreshAttempt> _refreshAccessTokenWithRefreshToken() async {
    final refreshToken = await _preferencesRepository.getAuthRefreshToken();
    if (refreshToken == null) {
      await discardSession();
      return const _RefreshSignedOut();
    }

    final response = await _refreshSessionCall(
      RefreshSessionBody(refreshToken: refreshToken),
    );

    switch (response) {
      case RefreshSessionResponseSuccess(:final data):
        await _applyAuthTokenResponse(data);
        return _RefreshSuccess(_requireAccessToken(_accessToken));
      case RefreshSessionResponseUnauthorized():
        await discardSession();
        return const _RefreshSignedOut();
      case RefreshSessionResponseServerError(:final data):
        throw AuthException(data.message);
      case RefreshSessionResponseUnknown(:final statusCode):
        if (statusCode == 401 || statusCode == 403) {
          await discardSession();
          return const _RefreshSignedOut();
        }
        throw AuthException('Refresh session failed (status: $statusCode).');
    }
  }

  Future<void> _applyAuthTokenResponse(AuthTokenResponse response) async {
    _accessToken = response.accessToken.trim();
    _tokenType = response.tokenType;
    _accessTokenExpiresAtUtc = DateTime.now().toUtc().add(
      Duration(seconds: response.expiresIn),
    );
    await _preferencesRepository.saveAuthRefreshToken(response.refreshToken);
    _setAuthState(AuthState.authenticated);
  }

  String _requireAccessToken(String? token) {
    final normalized = token?.trim();
    if (normalized == null || normalized.isEmpty) {
      throw const AuthException.authRequired();
    }
    return normalized;
  }

  void _setAuthState(AuthState next) {
    if (_authState == next) {
      return;
    }
    _authState = next;
    notifyListeners();
  }

  void _clearAccessToken() {
    _accessToken = null;
    _tokenType = 'Bearer';
    _accessTokenExpiresAtUtc = null;
  }

  bool _hasUsableCachedAccessToken() {
    final token = _accessToken;
    final expiresAt = _accessTokenExpiresAtUtc;
    if (token == null || token.trim().isEmpty || expiresAt == null) {
      return false;
    }

    final latestSafeUseUtc = expiresAt.subtract(accessTokenRefreshLeeway);
    return DateTime.now().toUtc().isBefore(latestSafeUseUtc);
  }

  StartOidcLoginBodyClientType _resolveClientType() {
    if (kIsWeb) {
      return StartOidcLoginBodyClientType.web;
    }

    if (PlatformCompat.isMobile) {
      return StartOidcLoginBodyClientType.mobile;
    }

    return StartOidcLoginBodyClientType.desktop;
  }

  _PkcePair _issuePkcePair() {
    final verifierBytes = Uint8List.fromList(
      List<int>.generate(64, (_) => _random.nextInt(256)),
    );
    final verifier = base64UrlEncode(verifierBytes).replaceAll('=', '');
    final challenge = _s256UrlEncode(verifier);
    return _PkcePair(codeVerifier: verifier, codeChallenge: challenge);
  }

  String _s256UrlEncode(String input) {
    final digest = crypto.sha256.convert(ascii.encode(input));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _extractErrorMessage(dynamic body, {required String fallback}) {
    if (body is Map) {
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}

sealed class _RefreshAttempt {
  const _RefreshAttempt();
}

final class _RefreshSuccess extends _RefreshAttempt {
  final String accessToken;

  const _RefreshSuccess(this.accessToken);
}

final class _RefreshSignedOut extends _RefreshAttempt {
  const _RefreshSignedOut();
}

class _PkcePair {
  final String codeVerifier;
  final String codeChallenge;

  const _PkcePair({required this.codeVerifier, required this.codeChallenge});
}
