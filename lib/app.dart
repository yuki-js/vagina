import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/api/auth_service.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/config/constants.dart';
import 'package:vagina/core/state/locale_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/home/screens/home.dart';
import 'package:vagina/feat/oobe/screens/oobe_flow.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Main application widget
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  AuthService get _auth => AppContainer.auth;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_handleAuthStateChanged);
    _bootstrapAppState();
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  void _handleAuthStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrapAppState() async {
    final preferences = AppContainer.preferences;
    final isFirst = await preferences.isFirstLaunch();
    final preferredLocaleCode = await preferences.getPreferredLocaleCode();

    ref.read(appLocaleCodeProvider.notifier).setLocaleCode(preferredLocaleCode);

    if (!isFirst) {
      await AppContainer.auth.getCurrentUser();
    }

    if (mounted) {
      setState(() {
        _isFirstLaunch = isFirst;
        _isLoading = false;
      });
    }
  }

  Locale? _resolveOverrideLocale(String? localeCode) {
    if (localeCode == null) {
      return null;
    }

    return Locale(localeCode);
  }

  Locale _resolveLocale(
    Locale? deviceLocale,
    Iterable<Locale> supportedLocales,
  ) {
    if (deviceLocale != null) {
      for (final supportedLocale in supportedLocales) {
        if (supportedLocale.languageCode == deviceLocale.languageCode) {
          return supportedLocale;
        }
      }
    }

    return supportedLocales.first;
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(appLocaleCodeProvider);
    final authState = _auth.authState;

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context).appTitle(Constants.appName),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: _resolveOverrideLocale(localeCode),
      localeResolutionCallback: (locale, supportedLocales) =>
          _resolveLocale(locale, supportedLocales),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _isLoading
          ? const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            )
          : _isFirstLaunch || authState == AuthState.signedOut
          ? const OobeFlowScreen()
          : const HomeScreen(),
    );
  }
}
