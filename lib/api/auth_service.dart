import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:vagina/api/generated/models/auth_token_response.dart';
import 'package:vagina/api/generated/models/exchange_oidc_login_body.dart';
import 'package:vagina/api/generated/models/logout_body.dart';
import 'package:vagina/api/generated/models/refresh_session_body.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body_code_challenge_method.dart';
import 'package:vagina/api/generated/models/start_oidc_login_body_client_type.dart';
import 'package:vagina/api/generated/responses/exchange_oidc_login_response.dart';
import 'package:vagina/api/generated/responses/get_current_user_response.dart';
import 'package:vagina/api/generated/responses/logout_response.dart';
import 'package:vagina/api/generated/responses/refresh_session_response.dart';
import 'package:vagina/api/generated/responses/start_oidc_login_response.dart';
import 'package:vagina/api/generated/models/user.dart';
import 'package:vagina/api/vagina_api_client.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/repositories/preferences_repository.dart';
import 'package:vagina/utils/platform_compat.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final String callbackUrl = AppConfig.callbackUrl;
  static const String defaultProvider = 'github';

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
  Future<String?>? _refreshInFlight;
  void Function()? onSignedOut;

  AuthService({
    required PreferencesRepository preferencesRepository,
    Random? random,
    VaginaApiClient Function(
      Future<String?> Function() accessTokenProvider,
      Future<String?> Function() onUnauthorizedRefresh,
    )?
    apiClientFactory,
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
      refreshAccessTokenAfterUnauthorized,
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
    Future<String?> Function() accessTokenProvider,
    Future<String?> Function() onUnauthorizedRefresh,
  ) {
    return VaginaApiClient(
      accessTokenProvider: accessTokenProvider,
      onUnauthorizedRefresh: onUnauthorizedRefresh,
    );
  }

  VaginaApiClient get apiClient => _apiClient;

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
      throw const AuthException(
        'Sign-in session expired. Please start sign-in again.',
      );
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
        throw AuthException(data.message);
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
    final token = await getAccessToken();
    if (token == null) {
      return null;
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
    if (refreshToken == null) {
      _clearAccessToken();
      await _preferencesRepository.clearPendingPkceVerifier();
      await _preferencesRepository.clearPendingOidcProvider();
      _notifySignedOut();
      return;
    }

    final response = await _logoutCall(LogoutBody(refreshToken: refreshToken));

    switch (response) {
      case LogoutResponseNoContent():
        await _clearSessionAndNotifySignedOut();
      case LogoutResponseUnknown(:final statusCode):
        if (statusCode == 204) {
          await _clearSessionAndNotifySignedOut();
          return;
        }
        throw AuthException('Logout failed (status: $statusCode).');
      case LogoutResponseServerError(:final data):
        throw AuthException(data.message);
    }
  }

  Future<String?> getAccessToken() async {
    if (_hasValidAccessToken()) {
      return _accessToken;
    }

    return _runRefreshSingleFlight();
  }

  Future<String?> refreshAccessTokenAfterUnauthorized() async {
    _clearAccessToken();
    return _runRefreshSingleFlight();
  }

  Future<String?> _runRefreshSingleFlight() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshAccessTokenInternal();
    _refreshInFlight = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<String?> _refreshAccessTokenInternal() async {
    final refreshToken = await _preferencesRepository.getAuthRefreshToken();
    if (refreshToken == null) {
      _clearAccessToken();
      return null;
    }

    final response = await _refreshSessionCall(
      RefreshSessionBody(refreshToken: refreshToken),
    );

    switch (response) {
      case RefreshSessionResponseSuccess(:final data):
        await _applyAuthTokenResponse(data);
        return _accessToken;
      case RefreshSessionResponseUnauthorized():
        await _clearSessionAndNotifySignedOut();
        return null;
      case RefreshSessionResponseServerError(:final data):
        throw AuthException(data.message);
      case RefreshSessionResponseUnknown(:final statusCode):
        if (statusCode == 401 || statusCode == 403) {
          await _clearSessionAndNotifySignedOut();
          return null;
        }
        throw AuthException('Refresh session failed (status: $statusCode).');
    }
  }

  Future<void> _applyAuthTokenResponse(AuthTokenResponse response) async {
    _accessToken = response.accessToken;
    _tokenType = response.tokenType;
    _accessTokenExpiresAtUtc = DateTime.now().toUtc().add(
      Duration(seconds: response.expiresIn),
    );
    await _preferencesRepository.saveAuthRefreshToken(response.refreshToken);
  }

  Future<void> _clearSessionAndNotifySignedOut() async {
    await _preferencesRepository.clearAuthRefreshToken();
    await _preferencesRepository.clearPendingPkceVerifier();
    await _preferencesRepository.clearPendingOidcProvider();
    _clearAccessToken();
    _notifySignedOut();
  }

  void _notifySignedOut() {
    onSignedOut?.call();
  }

  void _clearAccessToken() {
    _accessToken = null;
    _tokenType = 'Bearer';
    _accessTokenExpiresAtUtc = null;
  }

  bool _hasValidAccessToken() {
    final token = _accessToken;
    final expiresAt = _accessTokenExpiresAtUtc;
    if (token == null || token.isEmpty || expiresAt == null) {
      return false;
    }

    return DateTime.now().toUtc().isBefore(expiresAt);
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

class _PkcePair {
  final String codeVerifier;
  final String codeChallenge;

  const _PkcePair({required this.codeVerifier, required this.codeChallenge});
}
