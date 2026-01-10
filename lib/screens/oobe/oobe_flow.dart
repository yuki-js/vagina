import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'oobe_background.dart';
import 'welcome_screen.dart';
import 'authentication_screen.dart';
import 'manual_setup_screen.dart';
import 'permissions_screen.dart';
import 'dive_in_screen.dart';
import '../home/home_screen.dart';

/// Main OOBE flow coordinator with navigation and page management
class OOBEFlow extends ConsumerStatefulWidget {
  const OOBEFlow({super.key});

  @override
  ConsumerState<OOBEFlow> createState() => _OOBEFlowState();
}

class _OOBEFlowState extends ConsumerState<OOBEFlow> {
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

  void _completeOOBE() {
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
        transitionDuration: const Duration(milliseconds: 1200), // Slower for elegance
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
          // Slide transition for page changes
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ));

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
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
