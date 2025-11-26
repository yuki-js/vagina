import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A circular icon button with customizable appearance
class CircularIconButton extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// Called when the button is pressed
  final VoidCallback? onPressed;

  /// The size of the button
  final double size;

  /// The background color
  final Color? backgroundColor;

  /// The icon color
  final Color? iconColor;

  /// Whether the button is active/highlighted
  final bool isActive;

  /// The active background color
  final Color? activeBackgroundColor;

  const CircularIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 56,
    this.backgroundColor,
    this.iconColor,
    this.isActive = false,
    this.activeBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? (activeBackgroundColor ?? AppTheme.primaryColor)
        : (backgroundColor ?? AppTheme.surfaceColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppTheme.textPrimary,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
