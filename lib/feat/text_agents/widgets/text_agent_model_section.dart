import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/text_agents/controllers/text_agent_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class TextAgentModelSection extends StatelessWidget {
  final TextAgentFormController controller;

  const TextAgentModelSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final l10n = AppLocalizations.of(context);
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (controller.catalogStatus) {
            TextAgentCatalogStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            TextAgentCatalogStatus.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.errors.model ??
                      l10n.textAgentsLoadError(
                        controller.catalogError?.toString() ?? '',
                      ),
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: controller.loadModels,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.speedDialConfigVoiceAgentRetry),
                ),
              ],
            ),
            TextAgentCatalogStatus.ready => DropdownButtonFormField<String>(
              initialValue:
                  controller.models.any(
                    (model) => model.id == controller.draft.textModelId,
                  )
                  ? controller.draft.textModelId
                  : null,
              decoration: InputDecoration(
                labelText: '${l10n.textAgentsFieldModel} *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: const Icon(Icons.psychology_outlined),
                errorText: controller.errors.model,
              ),
              items: controller.models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model.id,
                      enabled: model.isAvailable,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            model.isDefault
                                ? '${model.displayName} (${l10n.textAgentsModelPresetDefault})'
                                : model.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: model.isAvailable
                                  ? AppTheme.lightTextPrimary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                          if (!model.isAvailable) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: AppTheme.lightTextSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) controller.updateTextModelId(value);
              },
            ),
          },
        ),
      );
    },
  );
}
