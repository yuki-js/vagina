import 'package:flutter/material.dart';
import 'package:vagina/feat/text_agents/controllers/text_agent_form_controller.dart';
import 'package:vagina/l10n/app_localizations.dart';

class TextAgentBasicInfoSection extends StatelessWidget {
  final TextAgentFormController controller;

  const TextAgentBasicInfoSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final l10n = AppLocalizations.of(context);
      final draft = controller.draft;
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
                key: ValueKey(('name', draft.name)),
                initialValue: draft.name,
                decoration: InputDecoration(
                  labelText: '${l10n.textAgentsFieldAgentName} *',
                  hintText: l10n.textAgentsFieldNameHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  errorText: controller.errors.name,
                ),
                textInputAction: TextInputAction.next,
                onChanged: controller.updateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey(('description', draft.description)),
                initialValue: draft.description,
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
                onChanged: controller.updateDescription,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey(('prompt', draft.prompt)),
                initialValue: draft.prompt,
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
                onChanged: controller.updatePrompt,
              ),
            ],
          ),
        ),
      );
    },
  );
}
