import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/feat/speed_dial/widgets/reasoning_effort_slider.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialReasoningSection extends StatelessWidget {
  final SpeedDialFormController controller;

  const SpeedDialReasoningSection({super.key, required this.controller});

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
                l10n.speedDialConfigReasoningEffortLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.speedDialConfigReasoningEffortHint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ReasoningEffortSlider(
                value: controller.draft.reasoningEffort,
                onChanged: controller.updateReasoningEffort,
              ),
            ],
          ),
        ),
      );
    },
  );
}
