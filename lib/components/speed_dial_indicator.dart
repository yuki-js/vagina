import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/speed_dial.dart';

/// スピードダイヤルインジケーター - 現在使用中のスピードダイヤルをさりげなく表示
class SpeedDialIndicator extends StatelessWidget {
  final SpeedDial speedDial;
  
  const SpeedDialIndicator({
    super.key,
    required this.speedDial,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (speedDial.iconEmoji != null) ...[
            Text(
              speedDial.iconEmoji!,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            speedDial.name,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
