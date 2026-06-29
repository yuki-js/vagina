import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/shared/widgets/tool_config_section.dart';
import 'package:vagina/feat/speed_dial/state/speed_dial_providers.dart';
import 'package:vagina/feat/speed_dial/widgets/emoji_picker.dart';
import 'package:vagina/feat/speed_dial/widgets/reasoning_effort_slider.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/models/voice_agent.dart';

/// Speed dial configuration screen
/// Accessed from speed dial tab when tapping on a speed dial
class SpeedDialConfigScreen extends ConsumerStatefulWidget {
  final String? speedDialId; // null for new speed dial
  final SpeedDial? speedDial; // null for new speed dial

  const SpeedDialConfigScreen({super.key, this.speedDialId, this.speedDial});

  @override
  ConsumerState<SpeedDialConfigScreen> createState() =>
      _SpeedDialConfigScreenState();
}

class _SpeedDialConfigScreenState extends ConsumerState<SpeedDialConfigScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late String _selectedVoice;
  late String _selectedVoiceAgentId;
  late String _selectedEmoji;
  late Map<String, bool> _enabledTools;
  late SpeedDialReasoningEffort _reasoningEffort;
  late bool _toolChoiceRequired;
  bool _isNewSpeedDial = false;
  List<VoiceAgent> _voiceAgents = const [];
  bool _isLoadingVoiceAgents = true;
  String? _voiceAgentLoadError;

  @override
  void initState() {
    super.initState();
    _isNewSpeedDial = widget.speedDial == null;

    if (_isNewSpeedDial) {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _instructionsController = TextEditingController();
      _selectedVoice = 'alloy';
      _selectedVoiceAgentId = SpeedDial.defaultVoiceAgentId;
      _selectedEmoji = '⭐';
      _enabledTools = {}; // Empty map = all tools enabled
      _reasoningEffort = SpeedDialReasoningEffort.off;
      _toolChoiceRequired = false;
    } else {
      _nameController = TextEditingController(text: widget.speedDial!.name);
      _descriptionController = TextEditingController(
        text: widget.speedDial!.description,
      );
      _instructionsController = TextEditingController(
        text: widget.speedDial!.systemPrompt,
      );
      _selectedVoice = widget.speedDial!.voice;
      _selectedVoiceAgentId = widget.speedDial!.voiceAgentId;
      _selectedEmoji = widget.speedDial!.iconEmoji ?? '⭐';
      _enabledTools = Map<String, bool>.from(widget.speedDial!.enabledTools);
      _reasoningEffort = widget.speedDial!.reasoningEffort;
      _toolChoiceRequired = widget.speedDial!.toolChoiceRequired;
    }

    _loadVoiceAgents();
  }

  Future<void> _loadVoiceAgents() async {
    try {
      final voiceAgents = await AppContainer.voiceAgents.listVoiceAgents();
      if (!mounted) return;

      final selectedExists = voiceAgents.any(
        (agent) => agent.id == _selectedVoiceAgentId,
      );
      var selectedVoiceAgentId = _selectedVoiceAgentId;
      if (!selectedExists && voiceAgents.isNotEmpty) {
        selectedVoiceAgentId = _defaultVoiceAgentId(voiceAgents);
      }

      setState(() {
        _voiceAgents = voiceAgents;
        _selectedVoiceAgentId = selectedVoiceAgentId;
        _isLoadingVoiceAgents = false;
        _voiceAgentLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _voiceAgents = const [];
        _isLoadingVoiceAgents = false;
        _voiceAgentLoadError = error.toString();
      });
    }
  }

  String _defaultVoiceAgentId(List<VoiceAgent> voiceAgents) {
    for (final voiceAgent in voiceAgents) {
      if (voiceAgent.isDefault) {
        return voiceAgent.id;
      }
    }
    return voiceAgents.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectEmoji() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: EmojiPicker(
            selectedEmoji: _selectedEmoji,
            onEmojiSelected: (emoji) {
              setState(() {
                _selectedEmoji = emoji;
              });
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    final l10n = AppLocalizations.of(context);

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.speedDialConfigNameRequired)));
      return;
    }

    if (_instructionsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speedDialConfigSystemPromptRequired)),
      );
      return;
    }

    if (_isLoadingVoiceAgents) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speedDialConfigVoiceAgentStillLoading)),
      );
      return;
    }

    if (_voiceAgentLoadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speedDialConfigVoiceAgentLoadFailed)),
      );
      return;
    }

    if (!_voiceAgents.any((agent) => agent.id == _selectedVoiceAgentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speedDialConfigVoiceAgentInvalidSelection)),
      );
      return;
    }

    final speedDialRepo = AppContainer.speedDials;
    final description = _descriptionController.text.trim();

    try {
      if (_isNewSpeedDial) {
        await speedDialRepo.create(
          name: _nameController.text,
          description: description.isEmpty ? null : description,
          systemPrompt: _instructionsController.text,
          voice: _selectedVoice,
          voiceAgentId: _selectedVoiceAgentId,
          iconEmoji: _selectedEmoji,
          enabledTools: Map<String, bool>.from(_enabledTools),
          reasoningEffort: _reasoningEffort,
          toolChoiceRequired: _toolChoiceRequired,
        );
      } else {
        await speedDialRepo.update(
          SpeedDial(
            id: widget.speedDial!.id,
            name: _nameController.text,
            description: description.isEmpty ? null : description,
            systemPrompt: _instructionsController.text,
            voice: _selectedVoice,
            voiceAgentId: _selectedVoiceAgentId,
            iconEmoji: _selectedEmoji,
            enabledTools: Map<String, bool>.from(_enabledTools),
            reasoningEffort: _reasoningEffort,
            toolChoiceRequired: _toolChoiceRequired,
            createdAt: widget.speedDial!.createdAt,
          ),
        );
      }
      ref.invalidate(speedDialsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNewSpeedDial
                  ? l10n.speedDialConfigAdded
                  : l10n.speedDialConfigUpdated,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _deleteSpeedDial() async {
    final l10n = AppLocalizations.of(context);

    if (_isNewSpeedDial) return;

    // Prevent deletion of default speed dial
    if (widget.speedDial!.id == SpeedDial.defaultId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speedDialConfigDefaultDeleteBlocked)),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.speedDialConfigDeleteConfirmTitle),
        content: Text(
          l10n.speedDialConfigDeleteConfirmBody(widget.speedDial!.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.settingsCommonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(l10n.settingsCommonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await AppContainer.speedDials.delete(widget.speedDial!.id);
        ref.invalidate(speedDialsProvider);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.speedDialConfigDeleted)));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isNewSpeedDial
              ? l10n.speedDialConfigAddTitle
              : l10n.speedDialConfigEditTitle,
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.lightTextPrimary,
        elevation: 0,
        actions: [
          // Hide delete button for default speed dial
          if (!_isNewSpeedDial && widget.speedDial!.id != SpeedDial.defaultId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSpeedDial,
              color: AppTheme.errorColor,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConfiguration,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AppTheme.primaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Emoji selection
            Card(
              child: InkWell(
                onTap: _selectEmoji,
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
                          _selectedEmoji,
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
            // Name configuration
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
                    TextField(
                      controller: _nameController,
                      enabled:
                          _isNewSpeedDial ||
                          widget.speedDial!.id !=
                              SpeedDial
                                  .defaultId, // Disable for default speed dial
                      decoration: InputDecoration(
                        hintText: l10n.speedDialConfigNameHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        helperText:
                            (!_isNewSpeedDial &&
                                widget.speedDial!.id == SpeedDial.defaultId)
                            ? l10n.speedDialConfigDefaultNameLocked
                            : null,
                      ),
                      style: const TextStyle(color: AppTheme.lightTextPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Description configuration
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
                    TextField(
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
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Voice selection
            Card(
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
                      initialValue: _selectedVoice,
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
                        DropdownMenuItem(
                          value: 'shimmer',
                          child: Text('Shimmer'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedVoice = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Voice agent selection
            Card(
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
                    if (_isLoadingVoiceAgents)
                      const Center(child: CircularProgressIndicator())
                    else if (_voiceAgentLoadError != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.speedDialConfigVoiceAgentLoadFailed,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoadingVoiceAgents = true;
                                _voiceAgentLoadError = null;
                              });
                              _loadVoiceAgents();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.speedDialConfigVoiceAgentRetry),
                          ),
                        ],
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue:
                            _voiceAgents.any(
                              (agent) => agent.id == _selectedVoiceAgentId,
                            )
                            ? _selectedVoiceAgentId
                            : null,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _voiceAgents
                            .map(
                              (agent) => DropdownMenuItem<String>(
                                value: agent.id,
                                child: Text(
                                  agent.isDefault
                                      ? l10n.speedDialConfigVoiceAgentDefault(
                                          agent.displayName,
                                        )
                                      : agent.displayName,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedVoiceAgentId = value;
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // System instructions
            Card(
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
                    TextField(
                      controller: _instructionsController,
                      decoration: InputDecoration(
                        hintText: l10n.speedDialConfigSystemPromptHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      style: const TextStyle(color: AppTheme.lightTextPrimary),
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tool Configuration Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.speedDialConfigToolsLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ToolConfigSection(
                      enabledTools: _enabledTools,
                      onChanged: (newTools) {
                        setState(() {
                          _enabledTools = newTools;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.speedDialConfigToolChoiceRequiredLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.lightTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        l10n.speedDialConfigToolChoiceRequiredHint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.lightTextSecondary,
                        ),
                      ),
                      value: _toolChoiceRequired,
                      activeColor: AppTheme.primaryColor,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        setState(() {
                          _toolChoiceRequired = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reasoning effort
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.speedDialConfigReasoningEffortLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.speedDialConfigReasoningEffortHint,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ReasoningEffortSlider(
                      value: _reasoningEffort,
                      onChanged: (value) {
                        setState(() {
                          _reasoningEffort = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Save button
            ElevatedButton(
              onPressed: _saveConfiguration,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isNewSpeedDial
                    ? l10n.speedDialConfigAddAction
                    : l10n.settingsCommonSave,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
