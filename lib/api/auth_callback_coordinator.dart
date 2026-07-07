import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/core/config/constants.dart';
import 'package:vagina/feat/oobe/utils/oidc_callback_parser.dart';
import 'package:vagina/utils/browser_history.dart';
import 'package:vagina/utils/platform_compat.dart';

enum AuthCallbackFailureReason {
  providerError,
  missingCodeOrState,
  exchangeFailed,
}

class AuthCallbackEvent {
  final bool isSuccess;
  final AuthCallbackFailureReason? failureReason;
  final String? detail;

  const AuthCallbackEvent._({
    required this.isSuccess,
    this.failureReason,
    this.detail,
  });

  const AuthCallbackEvent.success() : this._(isSuccess: true);

  const AuthCallbackEvent.failure(
    AuthCallbackFailureReason reason, {
    String? detail,
  }) : this._(isSuccess: false, failureReason: reason, detail: detail);
}

typedef MobileInitialLinkProvider = Future<Uri?> Function();
typedef MobileUriStreamProvider = Stream<Uri> Function();
typedef WebBaseUriProvider = Uri Function();
typedef ClearWebTransientParams = void Function();

class AuthCallbackCoordinator {
  final AuthService _authService;
  final bool _isWeb;
  final bool _isMobile;
  final MobileInitialLinkProvider? _mobileInitialLinkProvider;
  final MobileUriStreamProvider? _mobileUriStreamProvider;
  final WebBaseUriProvider _webBaseUriProvider;
  final ClearWebTransientParams _clearWebTransientParams;

  final StreamController<AuthCallbackEvent> _eventsController =
      StreamController<AuthCallbackEvent>.broadcast();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _mobileUriSubscription;
  bool _started = false;
  String? _lastHandledCallbackState;

  AuthCallbackCoordinator({
    required AuthService authService,
    bool? isWeb,
    bool? isMobile,
    MobileInitialLinkProvider? mobileInitialLinkProvider,
    MobileUriStreamProvider? mobileUriStreamProvider,
    WebBaseUriProvider? webBaseUriProvider,
    ClearWebTransientParams? clearWebTransientParams,
  }) : _authService = authService,
       _isWeb = isWeb ?? kIsWeb,
       _isMobile = isMobile ?? PlatformCompat.isMobile,
       _mobileInitialLinkProvider = mobileInitialLinkProvider,
       _mobileUriStreamProvider = mobileUriStreamProvider,
       _webBaseUriProvider = webBaseUriProvider ?? _defaultWebBaseUriProvider,
       _clearWebTransientParams =
           clearWebTransientParams ?? clearBrowserUrlTransientParams;

  Stream<AuthCallbackEvent> get events => _eventsController.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    if (_isWeb) {
      await _handlePotentialOidcCallback(
        _webBaseUriProvider(),
        clearWebQueryAfterRead: true,
      );
    }

    if (_isMobile) {
      final streamProvider =
          _mobileUriStreamProvider ?? _defaultMobileUriStreamProvider;
      _mobileUriSubscription = streamProvider().listen((uri) {
        unawaited(
          _handlePotentialOidcCallback(uri, clearWebQueryAfterRead: false),
        );
      });

      final initialLinkProvider =
          _mobileInitialLinkProvider ?? _defaultMobileInitialLinkProvider;
      final initialUri = await initialLinkProvider();
      if (initialUri != null) {
        await _handlePotentialOidcCallback(
          initialUri,
          clearWebQueryAfterRead: false,
        );
      }
    }
  }

  Future<void> dispose() async {
    await _mobileUriSubscription?.cancel();
    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
  }

  Future<void> _handlePotentialOidcCallback(
    Uri callbackUri, {
    required bool clearWebQueryAfterRead,
  }) async {
    if (!_isExpectedCallbackUri(callbackUri)) {
      return;
    }

    final hasRelevantQuery =
        callbackUri.queryParameters.containsKey('code') ||
        callbackUri.queryParameters.containsKey('state') ||
        callbackUri.queryParameters.containsKey('error');
    if (!hasRelevantQuery) {
      return;
    }

    if (_isWeb && clearWebQueryAfterRead) {
      _clearWebTransientParams();
    }

    final errorCode = callbackUri.queryParameters['error']?.trim();
    if (errorCode != null && errorCode.isNotEmpty) {
      final errorDescription = callbackUri.queryParameters['error_description']
          ?.trim();
      final detail = (errorDescription == null || errorDescription.isEmpty)
          ? errorCode
          : '$errorCode: $errorDescription';
      _emit(
        AuthCallbackEvent.failure(
          AuthCallbackFailureReason.providerError,
          detail: detail,
        ),
      );
      return;
    }

    final payload = OidcCallbackPayload.fromUri(callbackUri);
    if (payload == null) {
      _emit(
        const AuthCallbackEvent.failure(
          AuthCallbackFailureReason.missingCodeOrState,
        ),
      );
      return;
    }

    if (_lastHandledCallbackState == payload.state) {
      return;
    }
    _lastHandledCallbackState = payload.state;

    try {
      await _authService.exchangeOidcLogin(
        code: payload.code,
        state: payload.state,
      );
      _emit(const AuthCallbackEvent.success());
    } on AuthException catch (e) {
      _emit(
        AuthCallbackEvent.failure(
          AuthCallbackFailureReason.exchangeFailed,
          detail: e.message,
        ),
      );
    } catch (e) {
      _emit(
        AuthCallbackEvent.failure(
          AuthCallbackFailureReason.exchangeFailed,
          detail: e.toString(),
        ),
      );
    }
  }

  bool _isExpectedCallbackUri(Uri uri) {
    final expected = Uri.parse(Constants.oauthCallbackUrl);
    if (_matchesCallbackUri(uri, expected)) {
      return true;
    }

    if (_isWeb && kDebugMode) {
      final debugExpected = Uri.parse('http://localhost:3000${expected.path}');
      if (_matchesCallbackUri(uri, debugExpected)) {
        return true;
      }
    }

    return false;
  }

  bool _matchesCallbackUri(Uri actual, Uri expected) {
    final expectedPath = _normalizePath(expected.path);
    final actualPath = _normalizePath(actual.path);
    return actual.scheme == expected.scheme &&
        actual.host == expected.host &&
        _effectivePort(actual) == _effectivePort(expected) &&
        actualPath == expectedPath;
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) {
      return uri.port;
    }
    return switch (uri.scheme) {
      'https' => 443,
      'http' => 80,
      _ => -1,
    };
  }

  String _normalizePath(String path) {
    if (path.isEmpty) {
      return '/';
    }
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  Future<Uri?> _defaultMobileInitialLinkProvider() async {
    _appLinks ??= AppLinks();
    return _appLinks!.getInitialLink();
  }

  Stream<Uri> _defaultMobileUriStreamProvider() {
    _appLinks ??= AppLinks();
    return _appLinks!.uriLinkStream;
  }

  static Uri _defaultWebBaseUriProvider() => Uri.base;

  void _emit(AuthCallbackEvent event) {
    if (_eventsController.isClosed) {
      return;
    }
    _eventsController.add(event);
  }
}
