import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/feat/home/screens/home.dart';
import 'package:vagina/feat/oobe/screens/authentication.dart';
import 'package:vagina/feat/oobe/screens/dive_in.dart';
import 'package:vagina/feat/oobe/screens/manual_setup.dart';
import 'package:vagina/feat/oobe/screens/permissions.dart';
import 'package:vagina/feat/oobe/screens/welcome.dart';
import 'package:vagina/feat/oobe/widgets/oobe_background.dart';

/// Main OOBE flow coordinator with navigation and page management
class OobeFlowScreen extends ConsumerStatefulWidget {
  const OobeFlowScreen({super.key});

  @override
  ConsumerState<OobeFlowScreen> createState() => _OobeFlowScreenState();
}

class _OobeFlowScreenState extends ConsumerState<OobeFlowScreen> {
  int _currentPageIndex = 0;

  void _goToNextPage() {
    setState(() {
      _currentPageIndex++;
    });
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
    }
  }

  void _completeOOBE() async {
    // Mark first launch as completed using preferencesRepositoryProvider
    final preferences = ref.read(preferencesRepositoryProvider);
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

          var fadeTween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          var scaleTween = Tween(begin: 0.9, end: 1.0).chain(
            CurveTween(curve: curve),
          );

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: ScaleTransition(
              scale: animation.drive(scaleTween),
              child: child,
            ),
          );
        },
        transitionDuration:
            const Duration(milliseconds: 2000), // Elegant slow transition
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
          return FadeTransition(
            opacity: animation,
            child: child,
          );
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
          onManualSetup: _goToNextPage,
          onBack: _goToPreviousPage,
        );
      case 2:
        return ManualSetupScreen(
          key: const ValueKey('setup'),
          onContinue: _goToNextPage,
          onBack: _goToPreviousPage,
        );
      case 3:
        return PermissionsScreen(
          key: const ValueKey('permissions'),
          onContinue: _goToNextPage,
          onBack: _goToPreviousPage,
        );
      case 4:
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
