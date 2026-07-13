import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialPromptSection extends StatefulWidget {
  final SpeedDialFormController controller;

  const SpeedDialPromptSection({super.key, required this.controller});

  @override
  State<SpeedDialPromptSection> createState() => _SpeedDialPromptSectionState();
}

class _SpeedDialPromptSectionState extends State<SpeedDialPromptSection> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: widget.controller.draft.systemPrompt,
    );
    widget.controller.addListener(_syncFromDraft);
  }

  @override
  void didUpdateWidget(SpeedDialPromptSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncFromDraft);
    widget.controller.addListener(_syncFromDraft);
    _syncFromDraft();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromDraft);
    _promptController.dispose();
    super.dispose();
  }

  void _syncFromDraft() {
    final prompt = widget.controller.draft.systemPrompt;
    if (_promptController.text == prompt) return;
    final currentOffset = _promptController.selection.baseOffset;
    final offset = currentOffset < 0
        ? prompt.length
        : currentOffset > prompt.length
        ? prompt.length
        : currentOffset;
    _promptController.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
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
                controller: _promptController,
                decoration: InputDecoration(
                  hintText: l10n.speedDialConfigSystemPromptHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  errorText: widget.controller.errors.systemPrompt,
                ),
                style: const TextStyle(color: AppTheme.lightTextPrimary),
                maxLines: 8,
                onChanged: widget.controller.updateSystemPrompt,
              ),
            ],
          ),
        ),
      );
    },
  );
}
