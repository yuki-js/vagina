import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/services/realtime_api_client.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/utils/url_utils.dart';

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
      _showSnackBar('設定の読み込みに失敗しました', isError: true);
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
    if (_realtimeUrlController.text.trim().isEmpty) {
      _showSnackBar('Realtime URLを入力してください', isError: true);
      return;
    }

    final parsed =
        UrlUtils.parseAzureRealtimeUrl(_realtimeUrlController.text.trim());
    if (parsed == null) {
      _showSnackBar('Realtime URLの形式が正しくありません', isError: true);
      return;
    }

    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar('APIキーを入力してください', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    // Test connection before saving
    RealtimeApiClient? apiClient;
    try {
      apiClient = RealtimeApiClient();

      await apiClient
          .connect(
        _realtimeUrlController.text.trim(),
        _apiKeyController.text.trim(),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('接続がタイムアウトしました');
        },
      );

      await apiClient.disconnect();
      await apiClient.dispose();
      apiClient = null;

      // Connection successful, save the config
      final config = ref.read(configRepositoryProvider);
      await config.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await config.saveApiKey(_apiKeyController.text.trim());

      if (mounted) {
        widget.onContinue();
      }
    } catch (e) {
      _showSnackBar('接続に失敗しました: $e', isError: true);
      await apiClient?.disconnect();
      await apiClient?.dispose();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'AI設定',
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
                      'Azure OpenAI Realtime APIの接続情報を入力してください',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Realtime URL field
                    Text(
                      'Realtime URL',
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
                        hintText: 'https://your-resource.openai.azure.com/...',
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
                      'APIキー',
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
                        hintText: 'APIキーを入力',
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
                            : const Text(
                                '続ける',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Security notice
                    Text(
                      '認証情報はデバイス上に安全に保存されます。',
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
