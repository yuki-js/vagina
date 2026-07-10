import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/core/widgets/tool_config_section.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialToolsSection extends StatelessWidget {
  final SpeedDialFormController controller;

  const SpeedDialToolsSection({super.key, required this.controller});

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
                l10n.speedDialConfigToolsLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ToolConfigSection(
                enabledTools: controller.draft.enabledTools,
                onChanged: controller.updateEnabledTools,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.speedDialConfigToolChoiceRequiredLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTextPrimary,
                  ),
                ),
                subtitle: Text(
                  l10n.speedDialConfigToolChoiceRequiredHint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTextSecondary,
                  ),
                ),
                value: controller.draft.toolChoiceRequired,
                activeColor: AppTheme.primaryColor,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) =>
                    controller.updateToolChoiceRequired(value ?? false),
              ),
            ],
          ),
        ),
      );
    },
  );
}
