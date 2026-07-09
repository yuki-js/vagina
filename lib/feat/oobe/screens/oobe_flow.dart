import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vagina/api/auth_callback_coordinator.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/announcement/services/announcement_service.dart';
import 'package:vagina/feat/home/screens/home.dart';
import 'package:vagina/feat/oobe/screens/authentication.dart';
import 'package:vagina/feat/oobe/screens/dive_in.dart';
import 'package:vagina/feat/oobe/screens/permissions.dart';
import 'package:vagina/feat/oobe/screens/welcome.dart';
import 'package:vagina/feat/oobe/widgets/oobe_background.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Main OOBE flow coordinator with navigation and page management
class OobeFlowScreen extends StatefulWidget {
  const OobeFlowScreen({super.key});

  @override
  State<OobeFlowScreen> createState() => _OobeFlowScreenState();
}

class _OobeFlowScreenState extends State<OobeFlowScreen> {
  int _currentPageIndex = 0;
  bool _isAuthenticating = false;
  bool _isSignedIn = false;
  bool _isLoadingAuthProviders = true;
  List<AuthProvider> _authProviders = const <AuthProvider>[];
  String? _authProviderLoadError;
  late final AnnouncementService _announcementService;
  late final AuthService _authService;
  StreamSubscription<AuthCallbackEvent>? _authCallbackSubscription;

  @override
  void initState() {
    super.initState();
    _announcementService = AnnouncementService(
      preferencesRepository: AppContainer.preferences,
    );
    _authService = AppContainer.auth;
    _authCallbackSubscription = AppContainer.authCallbacks.events.listen((
      event,
    ) {
      unawaited(_handleAuthCallbackEvent(event));
    });
    unawaited(_restoreSignInStateIfAvailable());
    unawaited(_loadAuthProviders());
  }

  @override
  void dispose() {
    unawaited(_authCallbackSubscription?.cancel());
    _announcementService.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    setState(() {
      _currentPageIndex++;
    });
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppTheme.errorColor
            : isWarning
            ? AppTheme.warningColor
            : AppTheme.successColor,
      ),
    );
  }

  Future<void> _loadAuthProviders() async {
    if (mounted) {
      setState(() {
        _isLoadingAuthProviders = true;
        _authProviderLoadError = null;
      });
    }

    try {
      final providers = await _authService.listOidcProviders();
      if (!mounted) {
        return;
      }
      setState(() {
        _authProviders = providers
            .map(AuthProvider.fromApi)
            .toList(growable: false);
        _isLoadingAuthProviders = false;
        _authProviderLoadError = null;
      });
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authProviders = const <AuthProvider>[];
        _isLoadingAuthProviders = false;
        _authProviderLoadError = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authProviders = const <AuthProvider>[];
        _isLoadingAuthProviders = false;
        _authProviderLoadError = e.toString();
      });
    }
  }

  Future<void> _handleProviderTap(AuthProvider provider) async {
    await _startOidcLogin(provider.id);
  }

  Future<void> _startOidcLogin(String provider) async {
    if (_isAuthenticating) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authorizationUri = await _authService.startOidcLogin(
        provider: provider,
      );
      final launched = await launchUrl(
        authorizationUri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!launched) {
        throw const AuthException('Failed to open authorization URL.');
      }

      if (!kIsWeb) {
        _showSnackBar(l10n.oobeAuthenticationContinueInBrowser);
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(
        l10n.oobeAuthenticationStartFailed(e.message),
        isError: true,
      );
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      _showSnackBar(
        l10n.oobeAuthenticationStartFailed(e.toString()),
        isError: true,
      );
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _restoreSignInStateIfAvailable() async {
    await _syncSignInState();
  }

  Future<void> _handleAuthCallbackEvent(AuthCallbackEvent event) async {
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    if (event.isSuccess) {
      _showSnackBar(l10n.oobeAuthenticationSignInSuccess);
      setState(() {
        _isSignedIn = true;
        _isAuthenticating = false;
        if (_currentPageIndex <= 1) {
          _currentPageIndex = 2;
        }
      });
      return;
    }

    final reason = event.failureReason;
    final detail = event.detail?.trim();
    final message = reason == AuthCallbackFailureReason.missingCodeOrState
        ? l10n.oobeAuthenticationMissingAuthCode
        : (detail == null || detail.isEmpty)
        ? l10n.oobeAuthenticationMissingAuthCode
        : detail;

    _showSnackBar(
      l10n.oobeAuthenticationCallbackFailed(message),
      isError: true,
    );
    setState(() {
      _isSignedIn = false;
      _currentPageIndex = 1;
      _isAuthenticating = false;
    });
  }

  Future<void> _syncSignInState() async {
    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) {
        return;
      }

      if (user == null) {
        setState(() {
          _isSignedIn = false;
        });
        return;
      }

      setState(() {
        _isSignedIn = true;
        _isAuthenticating = false;
        if (_currentPageIndex <= 1) {
          _currentPageIndex = 2;
        }
      });
    } catch (_) {
      // Keep OOBE on auth prompt when session restoration fails.
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
    }
  }

  void _completeOOBE() async {
    final l10n = AppLocalizations.of(context);
    if (!_isSignedIn) {
      _showSnackBar(l10n.oobeAuthenticationSignInRequired, isError: true);
      setState(() {
        _currentPageIndex = 1;
      });
      return;
    }

    // Mark first launch as completed using preferencesRepositoryProvider
    final preferences = AppContainer.preferences;
    await preferences.markFirstLaunchCompleted();

    if (!mounted) return;

    // Navigate to HomeScreen with elegant transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Elegant fade and scale transition
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeInOutCubic;

          var fadeTween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          var scaleTween = Tween(
            begin: 0.9,
            end: 1.0,
          ).chain(CurveTween(curve: curve));

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: ScaleTransition(
              scale: animation.drive(scaleTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(
          milliseconds: 2000,
        ), // Elegant slow transition
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OOBEBackground(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Simple fade transition - more natural than slide
          return FadeTransition(opacity: animation, child: child);
        },
        child: _buildCurrentPage(),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPageIndex) {
      case 0:
        return WelcomeScreen(
          key: const ValueKey('welcome'),
          onContinue: _goToNextPage,
        );
      case 1:
        return AuthenticationScreen(
          key: const ValueKey('auth'),
          announcementService: _announcementService,
          providers: _authProviders,
          isLoadingProviders: _isLoadingAuthProviders,
          providerLoadError: _authProviderLoadError,
          onProviderTap: _handleProviderTap,
          isAuthenticating: _isAuthenticating,
          onRetryLoadProviders: () => unawaited(_loadAuthProviders()),
          onBack: _goToPreviousPage,
        );
      case 2:
        return PermissionsScreen(
          key: const ValueKey('permissions'),
          onContinue: _goToNextPage,
          onBack: _goToPreviousPage,
        );
      case 3:
        return DiveInScreen(
          key: const ValueKey('divein'),
          onStart: _completeOOBE,
          onBack: _goToPreviousPage,
        );
      default:
        return WelcomeScreen(
          key: const ValueKey('welcome'),
          onContinue: _goToNextPage,
        );
    }
  }
}
