import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';

class KeycapSequence extends StatelessWidget {
  final List<String> tokens;
  final bool isMuted;

  const KeycapSequence({super.key, required this.tokens, this.isMuted = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < tokens.length; index++) ...[
          if (index > 0) _KeycapSeparator(isMuted: isMuted),
          Keycap(token: tokens[index], isMuted: isMuted),
        ],
      ],
    );
  }
}

class Keycap extends StatelessWidget {
  final String token;
  final bool isMuted;

  const Keycap({super.key, required this.token, this.isMuted = false});

  @override
  Widget build(BuildContext context) {
    final borderColor = isMuted
        ? AppTheme.lightTextSecondary.withValues(alpha: 0.18)
        : AppTheme.primaryColor.withValues(alpha: 0.38);
    final backgroundColor = isMuted
        ? AppTheme.lightTextSecondary.withValues(alpha: 0.06)
        : AppTheme.primaryColor.withValues(alpha: 0.10);
    final foregroundColor = isMuted
        ? AppTheme.lightTextSecondary
        : AppTheme.lightTextPrimary;

    return Container(
      constraints: const BoxConstraints(minWidth: 34, minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        token,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _KeycapSeparator extends StatelessWidget {
  final bool isMuted;

  const _KeycapSeparator({required this.isMuted});

  @override
  Widget build(BuildContext context) {
    return Text(
      '+',
      style: TextStyle(
        color: isMuted
            ? AppTheme.lightTextSecondary
            : AppTheme.lightTextPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
