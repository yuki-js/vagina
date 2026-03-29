import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/utils/realtime_connection_test.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/utils/url_utils.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Third OOBE screen - Manual AI API configuration
class ManualSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const ManualSetupScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  ConsumerState<ManualSetupScreen> createState() => _ManualSetupScreenState();
}

class _ManualSetupScreenState extends ConsumerState<ManualSetupScreen> {
  final _realtimeUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isApiKeyVisible = false;
  bool _isSaving = false;

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
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n.settingsAzureLoadFailed, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveAndContinue() async {
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

    // Test connection before saving
    try {
      await testRealtimeConnection(
        _realtimeUrlController.text.trim(),
        _apiKeyController.text.trim(),
      );

      // Connection successful, save the config
      final config = ref.read(configRepositoryProvider);
      await config.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await config.saveApiKey(_apiKeyController.text.trim());

      if (mounted) {
        widget.onContinue();
      }
    } catch (e) {
      _showSnackBar(
        l10n.settingsAzureConnectionTestFailed(e.toString()),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Stack(
        children: [
          // メインコンテンツ - 中央寄せ
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      l10n.oobeManualSetupTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.oobeManualSetupSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Realtime URL field
                    Text(
                      l10n.settingsAzureRealtimeUrlLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _realtimeUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.settingsAzureRealtimeUrlHint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),

                    // API Key field
                    Text(
                      l10n.settingsAzureApiKeyLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: !_isApiKeyVisible,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.settingsAzureApiKeyHint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isApiKeyVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          onPressed: () {
                            setState(
                                () => _isApiKeyVisible = !_isApiKeyVisible);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.permissionsContinue,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Security notice
                    Text(
                      l10n.settingsAzureCredentialsStorageNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // 戻るボタン - 常に左上に固定
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
          ),
        ],
      ),
    );
  }
}
