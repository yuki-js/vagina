import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom painter for constellation game
class ConstellationPainter extends CustomPainter {
  final List<Offset> stars;
  final List<List<int>> connections;
  final int? selectedStarIndex;
  final double animation;

  ConstellationPainter({
    required this.stars,
    required this.connections,
    required this.selectedStarIndex,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections
    final linePaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final connection in connections) {
      final start = Offset(
        stars[connection[0]].dx * size.width,
        stars[connection[0]].dy * size.height,
      );
      final end = Offset(
        stars[connection[1]].dx * size.width,
        stars[connection[1]].dy * size.height,
      );
      canvas.drawLine(start, end, linePaint);
    }

    // Draw stars
    for (int i = 0; i < stars.length; i++) {
      final position = Offset(
        stars[i].dx * size.width,
        stars[i].dy * size.height,
      );

      final isSelected = i == selectedStarIndex;
      final twinkle = math.sin((animation + i * 0.1) * 2 * math.pi) * 0.5 + 0.5;

      // Glow effect
      final glowPaint = Paint()
        ..color = isSelected
            ? AppTheme.secondaryColor.withValues(alpha: 0.6 * twinkle)
            : AppTheme.primaryColor.withValues(alpha: 0.3 * twinkle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(position, isSelected ? 12 : 8, glowPaint);

      // Star
      final starPaint = Paint()
        ..color = isSelected
            ? AppTheme.secondaryColor
            : Colors.white.withValues(alpha: 0.8 + 0.2 * twinkle)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, isSelected ? 6 : 4, starPaint);

      // Selected star ring
      if (isSelected) {
        final ringPaint = Paint()
          ..color = AppTheme.secondaryColor.withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(position, 10, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.selectedStarIndex != selectedStarIndex ||
        oldDelegate.connections.length != connections.length;
  }
}
