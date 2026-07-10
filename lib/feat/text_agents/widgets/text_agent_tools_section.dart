import 'package:flutter/material.dart';
import 'package:vagina/core/widgets/tool_config_section.dart';
import 'package:vagina/feat/text_agents/controllers/text_agent_form_controller.dart';

class TextAgentToolsSection extends StatelessWidget {
  final TextAgentFormController controller;

  const TextAgentToolsSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => ToolConfigSection(
      enabledTools: controller.draft.enabledTools,
      onChanged: controller.updateEnabledTools,
    ),
  );
}
