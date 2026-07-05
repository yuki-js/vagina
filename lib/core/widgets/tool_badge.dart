import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';

class ToolBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  const ToolBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.active = false,
    this.onTap,
  });

  factory ToolBadge.fromStatus({
    Key? key,
    required String name,
    required String status,
    required VoidCallback onTap,
  }) {
    return ToolBadge(
      key: key,
      icon: _iconForStatus(status),
      label: name,
      color: _colorForStatus(status),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          if (active)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 12,
              color: color.withValues(alpha: 0.7),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(onTap: onTap, child: content);
  }

  static Color _colorForStatus(String status) {
    return switch (status) {
      'executing' || 'generating' => AppTheme.secondaryColor,
      'completed' => Colors.green,
      'error' => Colors.red,
      'cancelled' => Colors.grey,
      _ => Colors.green,
    };
  }

  static IconData _iconForStatus(String status) {
    return switch (status) {
      'error' => Icons.error_outline,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.build,
    };
  }
}
