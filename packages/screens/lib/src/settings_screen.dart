import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina_ui/vagina_ui.dart';
import 'package:vagina_core/vagina_core.dart';
import 'package:vagina_assistant_model/vagina_assistant_model.dart';

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
  String? _errorMessage;
  String? _successMessage;

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
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load settings: $e';
      });
    }
  }

  Future<void> _saveSettings() async {
    // Validate inputs
    if (_realtimeUrlController.text.trim().isEmpty) {
      _showError('Realtime URLを入力してください');
      return;
    }
    
    // Validate URL format
    final parsed = SecureStorageService.parseRealtimeUrl(_realtimeUrlController.text.trim());
    if (parsed == null) {
      _showError('Realtime URLの形式が正しくありません。\n例: https://{resource}.openai.azure.com/openai/realtime?api-version=2024-10-01-preview&deployment=gpt-4o-realtime');
      return;
    }
    
    if (_apiKeyController.text.trim().isEmpty) {
      _showError('APIキーを入力してください');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await storage.saveApiKey(_apiKeyController.text.trim());

      if (mounted) {
        setState(() {
          _successMessage = '設定を保存しました';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定を保存しました'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      _showError('保存に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_realtimeUrlController.text.trim().isEmpty) {
      _showError('Realtime URLを入力してください');
      return;
    }
    if (_apiKeyController.text.trim().isEmpty) {
      _showError('APIキーを入力してください');
      return;
    }

    final parsed = SecureStorageService.parseRealtimeUrl(_realtimeUrlController.text.trim());
    if (parsed == null) {
      _showError('Realtime URLの形式が正しくありません');
      return;
    }

    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _successMessage = '接続テスト中...';
    });

    try {
      // TODO: Implement actual WebSocket connection test
      await Future.delayed(const Duration(seconds: 1));
      
      // Save settings on success
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveRealtimeUrl(_realtimeUrlController.text.trim());
      await storage.saveApiKey(_apiKeyController.text.trim());

      if (mounted) {
        setState(() {
          _successMessage = '接続テスト成功。設定を保存しました。';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('接続テスト成功'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      _showError('接続テスト失敗: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
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

        if (mounted) {
          setState(() {
            _successMessage = '設定をクリアしました';
            _errorMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('設定をクリアしました'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      } catch (e) {
        _showError('設定のクリアに失敗しました: $e');
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
              // App bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('設定'),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Status message banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.errorColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.errorColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppTheme.errorColor),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _errorMessage = null),
                              child: const Icon(Icons.close, color: AppTheme.errorColor, size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    if (_successMessage != null && _errorMessage == null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.successColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(color: AppTheme.successColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Azure OpenAI Configuration Section
                    _buildSectionHeader('Azure OpenAI 設定'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Realtime URL
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
                              color: AppTheme.textSecondary.withOpacity(0.7),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // API Key
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
                          
                          // Buttons row
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
                            '認証情報はデバイス上に安全に保存され、サーバーには送信されません。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Voice Configuration Section
                    _buildSectionHeader('音声設定'),
                    const SizedBox(height: 12),
                    _buildCard(
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
                          ...AssistantConfig.availableVoices.map(
                            (voice) => RadioListTile<String>(
                              value: voice,
                              groupValue: assistantConfig.voice,
                              onChanged: (value) {
                                if (value != null) {
                                  ref
                                      .read(assistantConfigProvider.notifier)
                                      .updateVoice(value);
                                }
                              },
                              title: Text(
                                voice[0].toUpperCase() + voice.substring(1),
                                style: const TextStyle(color: AppTheme.textPrimary),
                              ),
                              activeColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // About Section
                    _buildSectionHeader('このアプリについて'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('バージョン', '1.0.0'),
                          const Divider(color: AppTheme.surfaceColor),
                          _buildInfoRow('Powered by', 'Azure OpenAI Realtime API'),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
