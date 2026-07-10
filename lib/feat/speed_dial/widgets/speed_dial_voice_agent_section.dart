import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialVoiceAgentSection extends StatelessWidget {
  final SpeedDialFormController controller;

  const SpeedDialVoiceAgentSection({super.key, required this.controller});

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
                l10n.speedDialConfigVoiceAgentLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.speedDialConfigVoiceAgentDescription,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              switch (controller.catalogStatus) {
                SpeedDialCatalogStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                SpeedDialCatalogStatus.failed => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.errors.voiceAgent ??
                          l10n.speedDialConfigVoiceAgentLoadFailed,
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: controller.loadVoiceAgents,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.speedDialConfigVoiceAgentRetry),
                    ),
                  ],
                ),
                SpeedDialCatalogStatus.ready => DropdownButtonFormField<String>(
                  initialValue:
                      controller.voiceAgents.any(
                        (agent) => agent.id == controller.draft.voiceAgentId,
                      )
                      ? controller.draft.voiceAgentId
                      : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    errorText: controller.errors.voiceAgent,
                  ),
                  items: controller.voiceAgents
                      .map(
                        (agent) => DropdownMenuItem(
                          value: agent.id,
                          enabled: agent.isAvailable,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                agent.isDefault
                                    ? l10n.speedDialConfigVoiceAgentDefault(
                                        agent.displayName,
                                      )
                                    : agent.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: agent.isAvailable
                                      ? AppTheme.lightTextPrimary
                                      : AppTheme.lightTextSecondary,
                                ),
                              ),
                              if (!agent.isAvailable) ...[
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
                    if (value != null) controller.updateVoiceAgentId(value);
                  },
                ),
              },
            ],
          ),
        ),
      );
    },
  );
}
