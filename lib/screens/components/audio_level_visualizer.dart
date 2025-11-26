import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Audio level visualizer with bouncing bars
class AudioLevelVisualizer extends StatelessWidget {
  final double level;
  final bool isMuted;
  final bool isConnected;
  final int barCount;
  final double height;
  
  const AudioLevelVisualizer({
    super.key,
    required this.level,
    required this.isMuted,
    required this.isConnected,
    this.barCount = 12,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          // Create a wave-like pattern with falloff from center
          final centerOffset = (i - barCount / 2).abs() / (barCount / 2);
          final falloff = 1 - centerOffset * 0.5;
          final barLevel = isMuted ? 0.0 : (pow(level, 0.9) * falloff).clamp(0.0, 1.0);
          
          // Minimum height percentage
          const minPct = 0.15;
          final pct = max(minPct, barLevel);
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            width: 6,
            height: height * pct,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isMuted 
                  ? AppTheme.textSecondary.withOpacity(0.3)
                  : (isConnected 
                      ? AppTheme.primaryColor.withOpacity(0.8 + barLevel * 0.2)
                      : AppTheme.textSecondary.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}
