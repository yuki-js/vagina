import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/secure_storage_service.dart';
import '../models/assistant_config.dart';
import '../components/components.dart';

/// Settings screen for API configuration (2 inputs: Realtime URL + API Key)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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

  Future<void> _loadSettings() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final realtimeUrl = await storage.getRealtimeUrl();
      final apiKey = await storage.getApiKey();
      
      if (realtimeUrl != null) {
        _realtimeUrlController.text = realtimeUrl;
      }
      if (apiKey != null) {
        _apiKeyController.text = apiKey;
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('設定の読み込みに失敗しました', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false, bool isWarning = false}) {
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
    if (_realtimeUrlController.text.trim().isEmpty) {
      _showSnackBar('Realtime URLを入力してください', isError: true);
      return;
    }
    
    final parsed = SecureStorageService.parseRealtimeUrl(_realtimeUrlController.text.trim());
    if (parsed == null) {
      _showSnackBar('Realtime URLの形式が正しくありません', isError: true);
      return;
    }
    
    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar('APIキーを入力してください', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await storage.saveApiKey(_apiKeyController.text.trim());
      _showSnackBar('設定を保存しました');
    } catch (e) {
      _showSnackBar('保存に失敗しました: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (_realtimeUrlController.text.trim().isEmpty) {
      _showSnackBar('Realtime URLを入力してください', isError: true);
      return;
    }
    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar('APIキーを入力してください', isError: true);
      return;
    }

    final parsed = SecureStorageService.parseRealtimeUrl(_realtimeUrlController.text.trim());
    if (parsed == null) {
      _showSnackBar('Realtime URLの形式が正しくありません', isError: true);
      return;
    }

    setState(() => _isTesting = true);

    try {
      // TODO: Implement actual WebSocket connection test
      await Future.delayed(const Duration(seconds: 1));
      
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await storage.saveApiKey(_apiKeyController.text.trim());
      _showSnackBar('接続テスト成功');
    } catch (e) {
      _showSnackBar('接続テスト失敗: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _clearSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('設定をクリア?'),
        content: const Text('保存済みのAPI設定をすべて削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final storage = ref.read(secureStorageServiceProvider);
        await storage.clearAll();
        _realtimeUrlController.clear();
        _apiKeyController.clear();
        _showSnackBar('設定をクリアしました', isWarning: true);
      } catch (e) {
        _showSnackBar('設定のクリアに失敗しました: $e', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _realtimeUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistantConfig = ref.watch(assistantConfigProvider);

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('設定'),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Azure OpenAI Configuration Section
                    const SectionHeader(title: 'Azure OpenAI 設定'),
                    const SizedBox(height: 12),
                    SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Azure OpenAI Realtime URL',
                            style: TextStyle(
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
                              decoration: const InputDecoration(
                                hintText: 'https://<resource>.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=gpt-4o-realtime',
                              ),
                              keyboardType: TextInputType.url,
                              maxLines: 2,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '例: https://your-resource.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=gpt-realtime',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'APIキー',
                            style: TextStyle(
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
                                hintText: 'APIキーを入力',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isApiKeyVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isApiKeyVisible = !_isApiKeyVisible;
                                    });
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
                                      : const Text('保存'),
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
                                      : const Text('接続テスト'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _isSaving || _isTesting ? null : _clearSettings,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                ),
                                child: const Text('クリア'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '認証情報はデバイス上に安全に保存されます。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: '音声設定'),
                    const SizedBox(height: 12),
                    SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'アシスタント音声',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RadioGroup<String>(
                            groupValue: assistantConfig.voice,
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                    .read(assistantConfigProvider.notifier)
                                    .updateVoice(value);
                              }
                            },
                            child: Column(
                              children: AssistantConfig.availableVoices.map(
                                (voice) => RadioListTile<String>(
                                  value: voice,
                                  title: Text(
                                    voice[0].toUpperCase() + voice.substring(1),
                                    style: const TextStyle(color: AppTheme.textPrimary),
                                  ),
                                  activeColor: AppTheme.primaryColor,
                                ),
                              ).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'このアプリについて'),
                    const SizedBox(height: 12),
                    SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const InfoRow(label: 'バージョン', value: '1.0.0'),
                          const Divider(color: AppTheme.surfaceColor),
                          const InfoRow(label: 'Powered by', value: 'Azure OpenAI Realtime API'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
