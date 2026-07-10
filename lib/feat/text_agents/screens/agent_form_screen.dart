import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/core/widgets/edit_form_error_banner.dart';
import 'package:vagina/core/widgets/unsaved_changes_bar.dart';
import 'package:vagina/feat/text_agents/controllers/text_agent_form_controller.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/feat/text_agents/widgets/text_agent_basic_info_section.dart';
import 'package:vagina/feat/text_agents/widgets/text_agent_model_section.dart';
import 'package:vagina/feat/text_agents/widgets/text_agent_tools_section.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/text_agent_definition.dart';

class AgentFormScreen extends ConsumerStatefulWidget {
  final TextAgentDefinition? agent;

  const AgentFormScreen({super.key, this.agent});

  @override
  ConsumerState<AgentFormScreen> createState() => _AgentFormScreenState();
}

class _AgentFormScreenState extends ConsumerState<AgentFormScreen> {
  final _emphasisRevision = ValueNotifier<int>(0);
  final _sectionKeys = {
    for (final section in TextAgentFormSection.values) section: GlobalKey(),
  };
  late final TextAgentFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextAgentFormController(
      repository: AppContainer.textAgents,
      modelRepository: AppContainer.textAgentModels,
      original: widget.agent,
    )..addListener(_rebuild);
    _controller.loadModels();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    _emphasisRevision.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  TextAgentFormValidationMessages _validationMessages(AppLocalizations l10n) =>
      TextAgentFormValidationMessages(
        nameRequired: l10n.textAgentsFieldRequired(
          l10n.textAgentsFieldAgentName,
        ),
        modelLoading: l10n.speedDialConfigVoiceAgentStillLoading,
        modelLoadFailed: l10n.textAgentsModelPresetsEmpty,
        modelInvalid: l10n.textAgentsModelPresetsEmpty,
      );

  Future<void> _save() async {
    final errors = _controller.validate(
      _validationMessages(AppLocalizations.of(context)),
    );
    if (!errors.isEmpty) {
      final target = _sectionKeys[errors.firstInvalidSection]?.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: 0.15,
        );
      }
      return;
    }
    final saved = await _controller.save(
      _validationMessages(AppLocalizations.of(context)),
    );
    if (!saved || !mounted) return;
    ref.invalidate(textAgentsProvider);
  }

  Future<void> _delete() async {
    final agent = widget.agent;
    if (agent == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.textAgentsDeleteDialogTitle),
        content: Text(l10n.textAgentsDeleteDialogBody(agent.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsCommonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsCommonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppContainer.textAgents.delete(agent.id);
    ref.invalidate(textAgentsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _controller.canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _emphasisRevision.value++;
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightBackgroundStart,
        appBar: AppBar(
          title: Text(
            _controller.isNew
                ? l10n.textAgentsCreateTitle
                : l10n.textAgentsEditTitle,
          ),
          actions: [
            if (!_controller.isNew && !_controller.isSaving)
              IconButton(
                icon: const Icon(Icons.delete),
                color: AppTheme.errorColor,
                onPressed: _delete,
              ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.lightBackgroundStart,
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
            AbsorbPointer(
              absorbing: _controller.isSaving,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  _controller.isDirty ? 150 : 24,
                ),
                children: [
                  if (_controller.saveError case final error?) ...[
                    EditFormErrorBanner(
                      message: l10n.unsavedChangesSaveFailed(error.toString()),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _SectionTitle(l10n.textAgentsSectionBasicInfo),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: _sectionKeys[TextAgentFormSection.basicInfo],
                    child: TextAgentBasicInfoSection(controller: _controller),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(l10n.textAgentsSectionSettings),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: _sectionKeys[TextAgentFormSection.model],
                    child: TextAgentModelSection(controller: _controller),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(l10n.textAgentsSectionToolSettings),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: _sectionKeys[TextAgentFormSection.tools],
                    child: TextAgentToolsSection(controller: _controller),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: AnimatedSlide(
                      offset: _controller.isDirty
                          ? Offset.zero
                          : const Offset(0, 1.35),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _controller.isDirty ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: IgnorePointer(
                          ignoring: !_controller.isDirty,
                          child: UnsavedChangesBar(
                            emphasisRevision: _emphasisRevision,
                            message: l10n.unsavedChangesMessage,
                            discardLabel: l10n.unsavedChangesDiscard,
                            compactDiscardLabel:
                                l10n.unsavedChangesDiscardCompact,
                            saveLabel: l10n.settingsCommonSave,
                            savingLabel: l10n.unsavedChangesSaving,
                            isSaving: _controller.isSaving,
                            onDiscard: _controller.isSaving
                                ? null
                                : _controller.discard,
                            onSave: _controller.isSaving ? null : _save,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppTheme.lightTextPrimary,
    ),
  );
}
