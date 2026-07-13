import 'package:flutter/material.dart';
import 'package:vagina/feat/text_agents/controllers/text_agent_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class TextAgentBasicInfoSection extends StatefulWidget {
  final TextAgentFormController controller;

  const TextAgentBasicInfoSection({super.key, required this.controller});

  @override
  State<TextAgentBasicInfoSection> createState() =>
      _TextAgentBasicInfoSectionState();
}

class _TextAgentBasicInfoSectionState extends State<TextAgentBasicInfoSection> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller.draft;
    _nameController = TextEditingController(text: draft.name);
    _descriptionController = TextEditingController(text: draft.description);
    _promptController = TextEditingController(text: draft.prompt);
    widget.controller.addListener(_syncFromDraft);
  }

  @override
  void didUpdateWidget(TextAgentBasicInfoSection oldWidget) {
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
    _promptController.dispose();
    super.dispose();
  }

  void _syncFromDraft() {
    final draft = widget.controller.draft;
    _syncText(_nameController, draft.name);
    _syncText(_descriptionController, draft.description);
    _syncText(_promptController, draft.prompt);
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
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${l10n.textAgentsFieldAgentName} *',
                  hintText: l10n.textAgentsFieldNameHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  errorText: widget.controller.errors.name,
                ),
                textInputAction: TextInputAction.next,
                onChanged: widget.controller.updateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.textAgentsFieldDescriptionOptional,
                  hintText: l10n.textAgentsFieldDescriptionHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
                textInputAction: TextInputAction.next,
                onChanged: widget.controller.updateDescription,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _promptController,
                decoration: InputDecoration(
                  labelText: l10n.textAgentsFieldSystemPromptOptional,
                  hintText: l10n.textAgentsFieldSystemPromptHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 5,
                textInputAction: TextInputAction.next,
                onChanged: widget.controller.updatePrompt,
              ),
            ],
          ),
        ),
      );
    },
  );
}
