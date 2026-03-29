import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/shared/widgets/tool_config_section.dart';
import 'package:vagina/feat/speed_dial/state/speed_dial_providers.dart';
import 'package:vagina/feat/speed_dial/widgets/emoji_picker.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/speed_dial.dart';

/// Speed dial configuration screen
/// Accessed from speed dial tab when tapping on a speed dial
class SpeedDialConfigScreen extends ConsumerStatefulWidget {
  final String? speedDialId; // null for new speed dial
  final SpeedDial? speedDial; // null for new speed dial

  const SpeedDialConfigScreen({
    super.key,
    this.speedDialId,
    this.speedDial,
  });

  @override
  ConsumerState<SpeedDialConfigScreen> createState() =>
      _SpeedDialConfigScreenState();
}

class _SpeedDialConfigScreenState extends ConsumerState<SpeedDialConfigScreen> {
  late TextEditingController _nameController;
  late TextEditingController _instructionsController;
  late String _selectedVoice;
  late String _selectedEmoji;
  late Map<String, bool> _enabledTools;
  bool _isNewSpeedDial = false;

  @override
  void initState() {
    super.initState();
    _isNewSpeedDial = widget.speedDial == null;

    if (_isNewSpeedDial) {
      _nameController = TextEditingController();
      _instructionsController = TextEditingController();
      _selectedVoice = 'alloy';
      _selectedEmoji = '⭐';
      _enabledTools = {}; // Empty map = all tools enabled
    } else {
      _nameController = TextEditingController(text: widget.speedDial!.name);
      _instructionsController =
          TextEditingController(text: widget.speedDial!.systemPrompt);
      _selectedVoice = widget.speedDial!.voice;
      _selectedEmoji = widget.speedDial!.iconEmoji ?? '⭐';
      _enabledTools = Map<String, bool>.from(widget.speedDial!.enabledTools);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speedDialConfigNameRequired)),
      );
      return;
    }

    if (_instructionsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.speedDialConfigSystemPromptRequired)),
      );
      return;
    }

    final speedDialRepo = ref.read(speedDialRepositoryProvider);
    final speedDial = SpeedDial(
      id: _isNewSpeedDial
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.speedDial!.id,
      name: _nameController.text,
      systemPrompt: _instructionsController.text,
      voice: _selectedVoice,
      iconEmoji: _selectedEmoji,
      enabledTools: _enabledTools,
      createdAt: _isNewSpeedDial ? DateTime.now() : widget.speedDial!.createdAt,
    );

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
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: Text(l10n.settingsCommonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(speedDialRepositoryProvider).delete(widget.speedDial!.id);
      ref.invalidate(speedDialsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.speedDialConfigDeleted)),
        );
        Navigator.of(context).pop();
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
                      enabled: _isNewSpeedDial ||
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
                        helperText: (!_isNewSpeedDial &&
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
                            value: 'shimmer', child: Text('Shimmer')),
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
