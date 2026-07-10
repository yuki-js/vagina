import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialPromptSection extends StatelessWidget {
  final SpeedDialFormController controller;

  const SpeedDialPromptSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final l10n = AppLocalizations.of(context);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.speedDialConfigSystemPromptLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.speedDialConfigSystemPromptDescription,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey(('prompt', controller.draft.systemPrompt)),
                initialValue: controller.draft.systemPrompt,
                decoration: InputDecoration(
                  hintText: l10n.speedDialConfigSystemPromptHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  errorText: controller.errors.systemPrompt,
                ),
                style: const TextStyle(color: AppTheme.lightTextPrimary),
                maxLines: 8,
                onChanged: controller.updateSystemPrompt,
              ),
            ],
          ),
        ),
      );
    },
  );
}
