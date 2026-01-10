import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Animated background for OOBE screens with stars and wave motifs
/// Fixed to bright/active state for elegant presentation
class OOBEBackground extends StatefulWidget {
  final Widget child;

  const OOBEBackground({
    super.key,
    required this.child,
  });

  @override
  State<OOBEBackground> createState() => _OOBEBackgroundState();
}

class _OOBEBackgroundState extends State<OOBEBackground>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: OOBEParticlePainter(
                    animation: _rotationController.value,
                    waveAnimation: _waveController.value,
                  ),
                );
              },
            ),
          ),
          // Child content
          widget.child,
        ],
      ),
    );
  }
}

/// Custom painter for animated particle background with stars and waves
class OOBEParticlePainter extends CustomPainter {
  final double animation;
  final double waveAnimation;

  OOBEParticlePainter({
    required this.animation,
    required this.waveAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw floating star particles (bright state)
    final particlePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppTheme.primaryColor.withValues(alpha: 0.3);

    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * math.pi + (animation * 2 * math.pi);
      final radius = (size.width / 2) * (0.3 + (i % 3) * 0.2);
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      final particleSize = 2.0 + (i % 3) * 1.0;

      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        particlePaint,
      );
    }

    // Draw wave rings (always active for bright state)
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.primaryColor.withValues(alpha: 0.2);

    for (int i = 0; i < 3; i++) {
      final waveRadius = 100.0 + (waveAnimation * 200.0 + i * 50) % 200.0;
      final alpha = 1.0 - ((waveAnimation + i * 0.33) % 1.0);

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        waveRadius,
        wavePaint..color = AppTheme.primaryColor.withValues(alpha: alpha * 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(OOBEParticlePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.waveAnimation != waveAnimation;
  }
}
