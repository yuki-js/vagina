import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialBasicInfoSection extends StatelessWidget {
  final SpeedDialFormController controller;
  final VoidCallback onSelectEmoji;

  const SpeedDialBasicInfoSection({
    super.key,
    required this.controller,
    required this.onSelectEmoji,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final l10n = AppLocalizations.of(context);
      final draft = controller.draft;
      final isDefault = controller.original?.isDefault ?? false;
      return Column(
        children: [
          Card(
            child: InkWell(
              onTap: onSelectEmoji,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.speedDialConfigIconLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        draft.emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        l10n.speedDialConfigIconTapToChange,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.speedDialConfigNameLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey(('name', draft.name)),
                    initialValue: draft.name,
                    enabled: !isDefault,
                    decoration: InputDecoration(
                      hintText: l10n.speedDialConfigNameHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      helperText: isDefault
                          ? l10n.speedDialConfigDefaultNameLocked
                          : null,
                      errorText: controller.errors.name,
                    ),
                    style: const TextStyle(color: AppTheme.lightTextPrimary),
                    onChanged: controller.updateName,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.speedDialConfigDescriptionLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey(('description', draft.description)),
                    initialValue: draft.description,
                    decoration: InputDecoration(
                      hintText: l10n.speedDialConfigDescriptionHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    style: const TextStyle(color: AppTheme.lightTextPrimary),
                    maxLines: 2,
                    onChanged: controller.updateDescription,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
