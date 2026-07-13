import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/core/widgets/edit_form_error_banner.dart';
import 'package:vagina/core/widgets/unsaved_changes_bar.dart';
import 'package:vagina/feat/speed_dial/controllers/speed_dial_form_controller.dart';
import 'package:vagina/feat/speed_dial/state/speed_dial_providers.dart';
import 'package:vagina/feat/speed_dial/widgets/emoji_picker.dart';
import 'package:vagina/feat/speed_dial/widgets/speed_dial_basic_info_section.dart';
import 'package:vagina/feat/speed_dial/widgets/speed_dial_prompt_section.dart';
import 'package:vagina/feat/speed_dial/widgets/speed_dial_tools_section.dart';
import 'package:vagina/feat/speed_dial/widgets/speed_dial_voice_agent_section.dart';
import 'package:vagina/feat/speed_dial/widgets/speed_dial_voice_section.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/speed_dial.dart';

class SpeedDialConfigScreen extends ConsumerStatefulWidget {
  final SpeedDial? speedDial;

  const SpeedDialConfigScreen({super.key, this.speedDial});

  @override
  ConsumerState<SpeedDialConfigScreen> createState() =>
      _SpeedDialConfigScreenState();
}

class _SpeedDialConfigScreenState extends ConsumerState<SpeedDialConfigScreen> {
  final _scrollController = ScrollController();
  final _emphasisRevision = ValueNotifier<int>(0);
  final _sectionKeys = {
    for (final section in SpeedDialFormSection.values) section: GlobalKey(),
  };
  late final SpeedDialFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SpeedDialFormController(
      speedDialRepository: AppContainer.speedDials,
      voiceAgentRepository: AppContainer.voiceAgents,
      original: widget.speedDial,
    )..addListener(_rebuild);
    _controller.loadVoiceAgents();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    _scrollController.dispose();
    _emphasisRevision.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  SpeedDialFormValidationMessages _validationMessages(AppLocalizations l10n) =>
      SpeedDialFormValidationMessages(
        nameRequired: l10n.speedDialConfigNameRequired,
        systemPromptRequired: l10n.speedDialConfigSystemPromptRequired,
        voiceAgentLoading: l10n.speedDialConfigVoiceAgentStillLoading,
        voiceAgentLoadFailed: l10n.speedDialConfigVoiceAgentLoadFailed,
        voiceAgentInvalid: l10n.speedDialConfigVoiceAgentInvalidSelection,
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
    ref.invalidate(speedDialsProvider);
  }

  Future<void> _selectEmoji() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: EmojiPicker(
            selectedEmoji: _controller.draft.emoji,
            onEmojiSelected: (emoji) {
              _controller.updateEmoji(emoji);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final speedDial = widget.speedDial;
    if (speedDial == null || speedDial.isDefault) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.speedDialConfigDeleteConfirmTitle),
        content: Text(l10n.speedDialConfigDeleteConfirmBody(speedDial.name)),
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
    await AppContainer.speedDials.delete(speedDial.id);
    ref.invalidate(speedDialsProvider);
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
                ? l10n.speedDialConfigAddTitle
                : l10n.speedDialConfigEditTitle,
          ),
          actions: [
            if (widget.speedDial case final dial?
                when !dial.isDefault && !_controller.isSaving)
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
                controller: _scrollController,
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
                  KeyedSubtree(
                    key: _sectionKeys[SpeedDialFormSection.basicInfo],
                    child: SpeedDialBasicInfoSection(
                      controller: _controller,
                      onSelectEmoji: _selectEmoji,
                    ),
                  ),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _sectionKeys[SpeedDialFormSection.voice],
                    child: SpeedDialVoiceSection(controller: _controller),
                  ),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _sectionKeys[SpeedDialFormSection.voiceAgent],
                    child: SpeedDialVoiceAgentSection(controller: _controller),
                  ),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _sectionKeys[SpeedDialFormSection.systemPrompt],
                    child: SpeedDialPromptSection(controller: _controller),
                  ),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _sectionKeys[SpeedDialFormSection.tools],
                    child: SpeedDialToolsSection(controller: _controller),
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
