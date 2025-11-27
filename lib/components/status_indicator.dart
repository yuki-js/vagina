import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Status indicator showing recording/mute state and call duration
class StatusIndicator extends StatelessWidget {
  final bool isMuted;
  final String duration;

  const StatusIndicator({
    super.key,
    required this.isMuted,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isMuted ? AppTheme.errorColor : AppTheme.successColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isMuted 
                ? 'ミュート中 • $duration'
                : '録音中 • $duration',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
