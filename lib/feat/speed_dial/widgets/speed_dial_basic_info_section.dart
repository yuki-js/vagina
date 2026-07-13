import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class SpeedDialBasicInfoSection extends StatefulWidget {
  final SpeedDialFormController controller;
  final VoidCallback onSelectEmoji;

  const SpeedDialBasicInfoSection({
    super.key,
    required this.controller,
    required this.onSelectEmoji,
  });

  @override
  State<SpeedDialBasicInfoSection> createState() =>
      _SpeedDialBasicInfoSectionState();
}

class _SpeedDialBasicInfoSectionState extends State<SpeedDialBasicInfoSection> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller.draft;
    _nameController = TextEditingController(text: draft.name);
    _descriptionController = TextEditingController(text: draft.description);
    widget.controller.addListener(_syncFromDraft);
  }

  @override
  void didUpdateWidget(SpeedDialBasicInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncFromDraft);
    widget.controller.addListener(_syncFromDraft);
    _syncFromDraft();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromDraft);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _syncFromDraft() {
    final draft = widget.controller.draft;
    _syncText(_nameController, draft.name);
    _syncText(_descriptionController, draft.description);
  }

  void _syncText(TextEditingController textController, String text) {
    if (textController.text == text) return;
    final currentOffset = textController.selection.baseOffset;
    final offset = currentOffset < 0
        ? text.length
        : currentOffset > text.length
        ? text.length
        : currentOffset;
    textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final l10n = AppLocalizations.of(context);
      final draft = widget.controller.draft;
      final isDefault = widget.controller.original?.isDefault ?? false;
      return Column(
        children: [
          Card(
            child: InkWell(
              onTap: widget.onSelectEmoji,
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
                    controller: _nameController,
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
                      errorText: widget.controller.errors.name,
                    ),
                    style: const TextStyle(color: AppTheme.lightTextPrimary),
                    onChanged: widget.controller.updateName,
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
                    controller: _descriptionController,
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
                    onChanged: widget.controller.updateDescription,
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
