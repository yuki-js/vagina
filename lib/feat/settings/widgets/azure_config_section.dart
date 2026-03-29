import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/utils/realtime_connection_test.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/utils/url_utils.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'settings_card.dart';

/// Azure OpenAI configuration section widget
class AzureConfigSection extends ConsumerStatefulWidget {
  const AzureConfigSection({super.key});

  @override
  ConsumerState<AzureConfigSection> createState() => _AzureConfigSectionState();
}

class _AzureConfigSectionState extends ConsumerState<AzureConfigSection> {
  final _realtimeUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final config = ref.read(configRepositoryProvider);

      final realtimeUrl = await config.getRealtimeUrl();
      final apiKey = await config.getApiKey();

      if (realtimeUrl != null) {
        _realtimeUrlController.text = realtimeUrl;
      }
      if (apiKey != null) {
        _apiKeyController.text = apiKey;
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

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context);

    if (_realtimeUrlController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsAzureRealtimeUrlRequired, isError: true);
      return;
    }

    final parsed =
        UrlUtils.parseAzureRealtimeUrl(_realtimeUrlController.text.trim());
    if (parsed == null) {
      _showSnackBar(l10n.settingsAzureRealtimeUrlInvalid, isError: true);
      return;
    }

    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar(l10n.settingsAzureApiKeyRequired, isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final config = ref.read(configRepositoryProvider);
      await config.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await config.saveApiKey(_apiKeyController.text.trim());
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

    final parsed =
        UrlUtils.parseAzureRealtimeUrl(_realtimeUrlController.text.trim());
    if (parsed == null) {
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
      await config.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await config.saveApiKey(_apiKeyController.text.trim());
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
