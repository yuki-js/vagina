import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/utils/realtime_connection_test.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'settings_card.dart';

/// OpenAI realtime configuration section widget.
class OpenAiConfigSection extends ConsumerStatefulWidget {
  const OpenAiConfigSection({super.key});

  @override
  ConsumerState<OpenAiConfigSection> createState() => _OpenAiConfigSectionState();
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
      final config = ref.read(configRepositoryProvider);

      final apiConfig = await config.getVoiceAgentApiConfig();
      switch (apiConfig) {
        case SelfhostedVoiceAgentApiConfig selfhostedConfig:
          _realtimeUrlController.text = selfhostedConfig.baseUrl;
          _apiKeyController.text = selfhostedConfig.apiKey;
          _transcriptionModelController.text =
              selfhostedConfig.transcriptionModel ?? _defaultTranscriptionModel;
        case HostedVoiceAgentApiConfig _:
          _transcriptionModelController.text = _defaultTranscriptionModel;
        case null:
          _transcriptionModelController.text = _defaultTranscriptionModel;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _isLoading = false);
        _showSnackBar(l10n.settingsAzureLoadFailed, isError: true);
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
      _showSnackBar(l10n.settingsAzureRealtimeUrlRequired, isError: true);
      return;
    }

    if (!_hasValidRealtimeBaseUri(_realtimeUrlController.text.trim())) {
      _showSnackBar(l10n.settingsAzureRealtimeUrlInvalid, isError: true);
      return;
    }

    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsAzureApiKeyRequired, isError: true);
      return;
    }

    final transcriptionModel = _resolvedTranscriptionModel();
    if (transcriptionModel.isEmpty) {
      _showSnackBar(
        l10n.settingsAzureTranscriptionModelRequired,
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final config = ref.read(configRepositoryProvider);
      final existingConfig = await config.getVoiceAgentApiConfig();
      final nextConfig = switch (existingConfig) {
        SelfhostedVoiceAgentApiConfig selfhostedConfig => selfhostedConfig.copyWith(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: transcriptionModel,
          ),
        HostedVoiceAgentApiConfig() => SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: transcriptionModel,
          ),
        null => SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: transcriptionModel,
          ),
        _ => SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: transcriptionModel,
          ),
      };
      await config.saveVoiceAgentApiConfig(nextConfig);
      _showSnackBar(l10n.settingsAzureSaveSuccess);
    } catch (e) {
      _showSnackBar(l10n.settingsAzureSaveFailed(e.toString()), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);

    if (_realtimeUrlController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsAzureRealtimeUrlRequired, isError: true);
      return;
    }
    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsAzureApiKeyRequired, isError: true);
      return;
    }

    if (!_hasValidRealtimeBaseUri(_realtimeUrlController.text.trim())) {
      _showSnackBar(l10n.settingsAzureRealtimeUrlInvalid, isError: true);
      return;
    }

    setState(() => _isTesting = true);

    try {
      await testRealtimeConnection(
        _realtimeUrlController.text.trim(),
        _apiKeyController.text.trim(),
      );

      final config = ref.read(configRepositoryProvider);
      final existingConfig = await config.getVoiceAgentApiConfig();
      final nextConfig = switch (existingConfig) {
        SelfhostedVoiceAgentApiConfig selfhostedConfig => selfhostedConfig.copyWith(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
        HostedVoiceAgentApiConfig() => SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
        null => SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
        _ => SelfhostedVoiceAgentApiConfig(
            providerType: VoiceAgentProviderType.openai,
            baseUrl: _realtimeUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
            transcriptionModel: _resolvedTranscriptionModel(),
          ),
      };
      await config.saveVoiceAgentApiConfig(nextConfig);
      _showSnackBar(l10n.settingsAzureConnectionTestSuccess);
    } catch (e) {
      _showSnackBar(
        l10n.settingsAzureConnectionTestFailed(e.toString()),
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
        title: Text(l10n.settingsAzureClearDialogTitle),
        content: Text(l10n.settingsAzureClearDialogBody),
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
        final config = ref.read(configRepositoryProvider);
        await config.clearAll();
        _realtimeUrlController.clear();
        _apiKeyController.clear();
        _transcriptionModelController.text = _defaultTranscriptionModel;
        _showSnackBar(l10n.settingsAzureClearSuccess, isWarning: true);
      } catch (e) {
        _showSnackBar(l10n.settingsAzureClearFailed(e.toString()), isError: true);
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
            l10n.settingsAzureRealtimeUrlLabel,
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
                hintText: l10n.settingsAzureRealtimeUrlHint,
              ),
              keyboardType: TextInputType.url,
              maxLines: 2,
            ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsAzureRealtimeUrlExample,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.settingsAzureApiKeyLabel,
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
                hintText: l10n.settingsAzureApiKeyHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isApiKeyVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _isApiKeyVisible = !_isApiKeyVisible);
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.settingsAzureTranscriptionModelLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (!_isLoading)
            RawAutocomplete<String>(
              textEditingController: _transcriptionModelController,
              focusNode: _transcriptionModelFocusNode,
              optionsBuilder: _transcriptionModelOptions,
              onSelected: (value) {
                _transcriptionModelController.value = TextEditingValue(
                  text: value,
                  selection: TextSelection.collapsed(offset: value.length),
                );
              },
              fieldViewBuilder:
                  (context, textEditingController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      enabled: !_isSaving && !_isTesting,
                      decoration: InputDecoration(
                        hintText: l10n.settingsAzureTranscriptionModelHint,
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
                      constraints: const BoxConstraints(maxHeight: 220),
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
            l10n.settingsAzureTranscriptionModelHelper,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
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
                      : Text(l10n.settingsAzureTestConnectionButton),
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
            l10n.settingsAzureCredentialsStorageNote,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
