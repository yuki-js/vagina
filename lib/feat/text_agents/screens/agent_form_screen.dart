import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/core/widgets/tool_config_section.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

/// Screen for creating or editing a server-backed text agent definition.
///
/// User-editable fields:
/// 1. Agent Name
/// 2. Description
/// 3. System Prompt
/// 4. Safe server-provided model preset
/// 5. Tool enablement
class AgentFormScreen extends ConsumerStatefulWidget {
  final TextAgentDefinition? agent; // null for new agent

  const AgentFormScreen({super.key, this.agent});

  @override
  ConsumerState<AgentFormScreen> createState() => _AgentFormScreenState();
}

class _AgentFormScreenState extends ConsumerState<AgentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _promptController;
  late Map<String, bool> _enabledTools;
  String? _selectedTextModelId;
  bool _isNewAgent = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isNewAgent = widget.agent == null;

    if (_isNewAgent) {
      _nameController = TextEditingController();
      _descriptionController = TextEditingController();
      _promptController = TextEditingController();
      _selectedTextModelId = null;
      _enabledTools = {};
    } else {
      final agent = widget.agent!;
      _nameController = TextEditingController(text: agent.name);
      _descriptionController = TextEditingController(
        text: agent.description ?? '',
      );
      _promptController = TextEditingController(text: agent.prompt);
      _selectedTextModelId = agent.textModelId;
      _enabledTools = Map<String, bool>.from(agent.enabledTools);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).textAgentsFieldRequired(fieldName);
    }
    return null;
  }

  Future<void> _saveAgent(List<TextAgentModelPreset> modelPresets) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final textModelId = _effectiveSelectedTextModelId(modelPresets);
    if (textModelId == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final description = _descriptionController.text.trim();
      final repository = AppContainer.textAgents;
      if (_isNewAgent) {
        await repository.create(
          name: _nameController.text.trim(),
          description: description.isEmpty ? null : description,
          prompt: _promptController.text.trim(),
          textModelId: textModelId,
          enabledTools: Map<String, bool>.from(_enabledTools),
        );
      } else {
        await repository.update(
          TextAgentDefinition(
            id: widget.agent!.id,
            name: _nameController.text.trim(),
            description: description.isEmpty ? null : description,
            prompt: _promptController.text.trim(),
            textModelId: textModelId,
            enabledTools: Map<String, bool>.from(_enabledTools),
            createdAt: widget.agent!.createdAt,
          ),
        );
      }

      if (mounted) {
        ref.invalidate(textAgentsProvider);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNewAgent
                  ? l10n.textAgentsSaveCreated
                  : l10n.textAgentsSaveUpdated,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.textAgentsSaveFailed(e.toString())),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteAgent() async {
    if (_isNewAgent) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.textAgentsDeleteDialogTitle),
          content: Text(l10n.textAgentsDeleteDialogBody(widget.agent!.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.settingsCommonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: Text(l10n.settingsCommonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final repository = AppContainer.textAgents;
        await repository.delete(widget.agent!.id);
        ref.invalidate(textAgentsProvider);

        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.textAgentsDeleteSuccess),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.textAgentsDeleteFailed(e.toString())),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final modelPresetsAsync = ref.watch(textAgentModelsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isNewAgent ? l10n.textAgentsCreateTitle : l10n.textAgentsEditTitle,
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.lightTextPrimary,
        elevation: 0,
        actions: [
          if (!_isNewAgent)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteAgent,
              color: AppTheme.errorColor,
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveAction(modelPresetsAsync),
              tooltip: l10n.settingsCommonSave,
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Basic Information Section
              _buildSectionHeader(l10n.textAgentsSectionBasicInfo),
              const SizedBox(height: 12),
              _buildCard(
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
                      ),
                      validator: (value) => _validateRequired(
                        value,
                        l10n.textAgentsFieldAgentName,
                      ),
                      textInputAction: TextInputAction.next,
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Safe model preset section
              _buildSectionHeader(l10n.textAgentsSectionSettings),
              const SizedBox(height: 12),
              _buildCard(
                child: _buildModelPresetField(modelPresetsAsync, l10n),
              ),
              const SizedBox(height: 24),

              // Tool Configuration Section
              _buildSectionHeader(l10n.textAgentsSectionToolSettings),
              const SizedBox(height: 12),
              ToolConfigSection(
                enabledTools: _enabledTools,
                onChanged: (newTools) {
                  setState(() {
                    _enabledTools = newTools;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _saveAction(modelPresetsAsync),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _isNewAgent
                            ? l10n.textAgentsActionCreate
                            : l10n.settingsCommonSave,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _saveAction(
    AsyncValue<List<TextAgentModelPreset>> presetsAsync,
  ) {
    if (_isSaving) {
      return null;
    }
    return presetsAsync.maybeWhen(
      data: (presets) => presets.isEmpty ? null : () => _saveAgent(presets),
      orElse: () => null,
    );
  }

  Widget _buildModelPresetField(
    AsyncValue<List<TextAgentModelPreset>> presetsAsync,
    AppLocalizations l10n,
  ) {
    return presetsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Text(
        l10n.textAgentsLoadError(error.toString()),
        style: const TextStyle(color: AppTheme.errorColor),
      ),
      data: (presets) {
        if (presets.isEmpty) {
          return Text(
            l10n.textAgentsModelPresetsEmpty,
            style: const TextStyle(color: AppTheme.errorColor),
          );
        }

        final selectedModelId = _effectiveSelectedTextModelId(presets);
        return DropdownButtonFormField<String>(
          initialValue: selectedModelId,
          decoration: InputDecoration(
            labelText: '${l10n.textAgentsFieldModel} *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.psychology_outlined),
          ),
          items: presets.map((preset) {
            return DropdownMenuItem(
              value: preset.id,
              child: Text(_modelPresetLabel(preset, l10n)),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _selectedTextModelId = value;
            });
          },
          validator: (value) =>
              _validateRequired(value, l10n.textAgentsFieldModel),
        );
      },
    );
  }

  String? _effectiveSelectedTextModelId(List<TextAgentModelPreset> presets) {
    if (presets.isEmpty) {
      return null;
    }

    final selectedTextModelId = _selectedTextModelId;
    if (selectedTextModelId != null &&
        presets.any((preset) => preset.id == selectedTextModelId)) {
      return selectedTextModelId;
    }

    final defaultPreset = presets
        .where((preset) => preset.isDefault)
        .firstOrNull;
    return defaultPreset?.id ?? presets.first.id;
  }

  String _modelPresetLabel(TextAgentModelPreset preset, AppLocalizations l10n) {
    if (!preset.isDefault) {
      return preset.displayName;
    }
    return '${preset.displayName} (${l10n.textAgentsModelPresetDefault})';
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.lightTextPrimary,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
