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
  late String _selectedEmoji;
  late Map<String, bool> _enabledTools;
  late SpeedDialReasoningEffort _reasoningEffort;
  late bool _toolChoiceRequired;
  bool _isNewSpeedDial = false;

  @override
  void initState() {
    super.initState();
    _isNewSpeedDial = widget.speedDial == null;

    if (_isNewSpeedDial) {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _instructionsController = TextEditingController();
      _selectedVoice = 'alloy';
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
      _selectedEmoji = widget.speedDial!.iconEmoji ?? '⭐';
      _enabledTools = Map<String, bool>.from(widget.speedDial!.enabledTools);
      _reasoningEffort = widget.speedDial!.reasoningEffort;
      _toolChoiceRequired = widget.speedDial!.toolChoiceRequired;
    }
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

    final speedDialRepo = AppContainer.speedDials;
    final speedDial = SpeedDial(
      id: _isNewSpeedDial
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.speedDial!.id,
      name: _nameController.text,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      systemPrompt: _instructionsController.text,
      voice: _selectedVoice,
      iconEmoji: _selectedEmoji,
      enabledTools: _enabledTools,
      reasoningEffort: _reasoningEffort,
      toolChoiceRequired: _toolChoiceRequired,
      createdAt: _isNewSpeedDial ? DateTime.now() : widget.speedDial!.createdAt,
    );

    try {
      if (_isNewSpeedDial) {
        await speedDialRepo.save(speedDial);
      } else {
        await speedDialRepo.update(speedDial);
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
