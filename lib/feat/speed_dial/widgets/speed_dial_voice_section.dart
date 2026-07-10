import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialVoiceSection extends StatelessWidget {
  final SpeedDialFormController controller;

  const SpeedDialVoiceSection({super.key, required this.controller});

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
                l10n.speedDialConfigVoiceLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: controller.draft.voice,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: const [
                  DropdownMenuItem(value: 'alloy', child: Text('Alloy')),
                  DropdownMenuItem(value: 'echo', child: Text('Echo')),
                  DropdownMenuItem(value: 'shimmer', child: Text('Shimmer')),
                ],
                onChanged: (value) {
                  if (value != null) controller.updateVoice(value);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
