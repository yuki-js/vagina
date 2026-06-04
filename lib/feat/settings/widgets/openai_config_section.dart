import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/realtime/realtime_adapter_factory.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'settings_card.dart';

/// OpenAI realtime configuration section widget.
class OpenAiConfigSection extends ConsumerStatefulWidget {
  const OpenAiConfigSection({super.key});

  @override
  ConsumerState<OpenAiConfigSection> createState() =>
      _OpenAiConfigSectionState();
}

class _OpenAiConfigSectionState extends ConsumerState<OpenAiConfigSection> {
  static const String _defaultTranscriptionModel = 'gpt-4o-mini-transcribe';
  static const List<String> _transcriptionModelPresets = <String>[
    'gpt-4o-mini-transcribe',
    'gpt-4o-transcribe',
  ];

  final _realtimeUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _transcriptionModelController = TextEditingController();
  final _transcriptionModelFocusNode = FocusNode();
  bool _isApiKeyVisible = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  VoiceAgentProviderType _providerType = VoiceAgentProviderType.openai;
  VoiceAgentModality _selectedModality = VoiceAgentModality.audio;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _realtimeUrlController.dispose();
    _apiKeyController.dispose();
    _transcriptionModelController.dispose();
    _transcriptionModelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final config = RepositoryFactory.config;

      final apiConfig = await config.getVoiceAgentApiConfig();
      switch (apiConfig) {
        case SelfhostedVoiceAgentApiConfig selfhostedConfig:
          _realtimeUrlController.text = selfhostedConfig.baseUrl;
          _apiKeyController.text = selfhostedConfig.apiKey;
          _transcriptionModelController.text =
              selfhostedConfig.transcriptionModel ?? _defaultTranscriptionModel;
          _providerType = selfhostedConfig.providerType;
          _selectedModality = selfhostedConfig.modality;
        case HostedVoiceAgentApiConfig _:
          _transcriptionModelController.text = _defaultTranscriptionModel;
          _providerType = VoiceAgentProviderType
              .openai; // todo: handle hosted config properly
          _selectedModality = VoiceAgentModality.audio;
        case null:
          _transcriptionModelController.text = _defaultTranscriptionModel;
          _providerType = VoiceAgentProviderType
              .openai; // todo: handle null config properly
          _selectedModality = VoiceAgentModality.audio;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _isLoading = false);
        _showSnackBar(l10n.settingsOpenAiLoadFailed, isError: true);
      }
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppTheme.errorColor
            : isWarning
                ? AppTheme.warningColor
                : AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _hasValidRealtimeBaseUri(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty;
  }

  Iterable<String> _transcriptionModelOptions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _transcriptionModelPresets;
    }

    return _transcriptionModelPresets.where(
      (model) => model.toLowerCase().contains(query),
    );
  }

  String _resolvedTranscriptionModel() {
    return _transcriptionModelController.text.trim();
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context);

    if (_realtimeUrlController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsOpenAiUrlRequired, isError: true);
      return;
    }

    if (!_hasValidRealtimeBaseUri(_realtimeUrlController.text.trim())) {
      _showSnackBar(l10n.settingsOpenAiUrlInvalid, isError: true);
      return;
    }

    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsOpenAiApiKeyRequired, isError: true);
      return;
    }

    final transcriptionModel = _resolvedTranscriptionModel();
    if (transcriptionModel.isEmpty) {
      _showSnackBar(
        l10n.settingsOpenAiTranscriptionModelRequired,
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final config = RepositoryFactory.config;
      final existingConfig = await config.getVoiceAgentApiConfig();
      final nextConfig = switch (existingConfig) {
        SelfhostedVoiceAgentApiConfig selfhostedConfig =>
          selfhostedConfig.copyWith(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: transcriptionModel,
          ),
        HostedVoiceAgentApiConfig() => SelfhostedVoiceAgentApiConfig(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: transcriptionModel,
          ),
        null => SelfhostedVoiceAgentApiConfig(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: transcriptionModel,
          ),
        _ => SelfhostedVoiceAgentApiConfig(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: transcriptionModel,
          ),
      };
      await config.saveVoiceAgentApiConfig(nextConfig);
      _showSnackBar(l10n.settingsOpenAiSaveSuccess);
    } catch (e) {
      _showSnackBar(l10n.settingsOpenAiSaveFailed(e.toString()), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);

    if (_realtimeUrlController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsOpenAiUrlRequired, isError: true);
      return;
    }
    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsOpenAiApiKeyRequired, isError: true);
      return;
    }

    if (!_hasValidRealtimeBaseUri(_realtimeUrlController.text.trim())) {
      _showSnackBar(l10n.settingsOpenAiUrlInvalid, isError: true);
      return;
    }

    setState(() => _isTesting = true);

    try {
      final testConfig = SelfhostedVoiceAgentApiConfig(
        providerType: _providerType,
        baseUrl: _realtimeUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        modality: _selectedModality,
        transcriptionModel: _resolvedTranscriptionModel(),
      );

      await RealtimeAdapterFactory.testConnection(testConfig);

      final config = RepositoryFactory.config;
      final existingConfig = await config.getVoiceAgentApiConfig();
      final nextConfig = switch (existingConfig) {
        SelfhostedVoiceAgentApiConfig selfhostedConfig =>
          selfhostedConfig.copyWith(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
        HostedVoiceAgentApiConfig() => SelfhostedVoiceAgentApiConfig(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
        null => SelfhostedVoiceAgentApiConfig(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
        _ => SelfhostedVoiceAgentApiConfig(
            providerType: _providerType,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            modality: _selectedModality,
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
      };
      await config.saveVoiceAgentApiConfig(nextConfig);
      _showSnackBar(l10n.settingsOpenAiConnectionTestSuccess);
    } catch (e) {
      _showSnackBar(
        l10n.settingsOpenAiConnectionTestFailed(e.toString()),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _clearSettings() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightSurfaceColor,
        title: Text(l10n.settingsOpenAiClearDialogTitle),
        content: Text(l10n.settingsOpenAiClearDialogBody),
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

    if (confirmed == true) {
      try {
        final config = RepositoryFactory.config;
        await config.clearAll();
        _realtimeUrlController.clear();
        _apiKeyController.clear();
        _transcriptionModelController.text = _defaultTranscriptionModel;
        _showSnackBar(l10n.settingsOpenAiClearSuccess, isWarning: true);
      } catch (e) {
        _showSnackBar(l10n.settingsOpenAiClearFailed(e.toString()),
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsOpenAiConnectionType,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<VoiceAgentProviderType>(
              value: _providerType,
              dropdownColor: AppTheme.lightSurfaceColor,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem(
                  value: VoiceAgentProviderType.openai,
                  child: Text(l10n.settingsOpenAiConnectionTypeOpenAi),
                ),
                DropdownMenuItem(
                  value: VoiceAgentProviderType.openaiCc,
                  child: Text(l10n.settingsOpenAiConnectionTypeOpenAiCc),
                ),
                DropdownMenuItem(
                  value: VoiceAgentProviderType.gemini,
                  child: Text(l10n.settingsOpenAiConnectionTypeGemini),
                ),
              ],
              onChanged: _isSaving || _isTesting
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _providerType = val);
                      }
                    },
            ),
          const SizedBox(height: 16),
          if (_providerType != VoiceAgentProviderType.gemini) ...[
            Text(
              l10n.settingsOpenAiUrlLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              TextField(
                controller: _realtimeUrlController,
                decoration: InputDecoration(
                  hintText: l10n.settingsOpenAiUrlHint,
                ),
                keyboardType: TextInputType.url,
                maxLines: 2,
              ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsOpenAiUrlExample,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.settingsOpenAiApiKeyLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (!_isLoading)
              TextField(
                controller: _apiKeyController,
                obscureText: !_isApiKeyVisible,
                decoration: InputDecoration(
                  hintText: l10n.settingsOpenAiApiKeyHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isApiKeyVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _isApiKeyVisible = !_isApiKeyVisible);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (!_isLoading)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsOpenAiModalityLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<VoiceAgentModality>(
                          value: _selectedModality,
                          dropdownColor: AppTheme.lightSurfaceColor,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: VoiceAgentModality.audio,
                              child: Text('audio'),
                            ),
                            DropdownMenuItem(
                              value: VoiceAgentModality.text,
                              child: Text('text'),
                            ),
                          ],
                          onChanged: _isSaving || _isTesting
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() => _selectedModality = val);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsOpenAiTranscriptionModelLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RawAutocomplete<String>(
                          textEditingController: _transcriptionModelController,
                          focusNode: _transcriptionModelFocusNode,
                          optionsBuilder: _transcriptionModelOptions,
                          onSelected: (value) {
                            _transcriptionModelController.value =
                                TextEditingValue(
                              text: value,
                              selection:
                                  TextSelection.collapsed(offset: value.length),
                            );
                          },
                          fieldViewBuilder: (context, textEditingController,
                              focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              enabled: !_isSaving && !_isTesting,
                              decoration: InputDecoration(
                                hintText:
                                    l10n.settingsOpenAiTranscriptionModelHint,
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                              ),
                              onSubmitted: (_) => onFieldSubmitted(),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            final optionList = options.toList();
                            if (optionList.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 220),
                                  child: SizedBox(
                                    width: 320,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: optionList.length,
                                      itemBuilder: (context, index) {
                                        final option = optionList[index];
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            child: Text(option),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.settingsOpenAiTranscriptionModelHelper,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving || _isTesting ? null : _saveSettings,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.settingsCommonSave),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving || _isTesting ? null : _testConnection,
                    child: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.settingsOpenAiTestConnectionButton),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isSaving || _isTesting ? null : _clearSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                  child: Text(l10n.settingsCommonClear),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsOpenAiCredentialsStorageNote,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.construction_rounded,
                      size: 48,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.settingsOpenAiConnectionTypeGeminiWarning,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
