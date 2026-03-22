import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';

class CallScreenShell extends StatelessWidget {
  final Widget child;

  const CallScreenShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF07111A),
                Color(0xFF102B33),
                Color(0xFF3E2A1F),
                Color(0xFF090B10),
              ],
              stops: [0.0, 0.36, 0.74, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                top: -120,
                left: -80,
                child: _GradientGlow(
                  size: 320,
                  color: Color(0xFF1F8A70),
                  opacity: 0.18,
                ),
              ),
              const Positioned(
                right: -110,
                bottom: -90,
                child: _GradientGlow(
                  size: 360,
                  color: Color(0xFFE0A458),
                  opacity: 0.14,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GradientGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.45),
              Colors.transparent,
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      ),
    );
  }
}
