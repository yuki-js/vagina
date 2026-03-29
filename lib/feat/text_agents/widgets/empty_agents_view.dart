import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Widget displayed when no text agents exist
class EmptyAgentsView extends StatelessWidget {
  final VoidCallback onCreateAgent;

  const EmptyAgentsView({
    super.key,
    required this.onCreateAgent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 80,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.textAgentsEmptyViewTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.textAgentsEmptyViewBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onCreateAgent,
            icon: const Icon(Icons.add),
            label: Text(l10n.textAgentsEmptyViewCreateAction),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
