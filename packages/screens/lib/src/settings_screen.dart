import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina_ui/vagina_ui.dart';
import 'package:vagina_core/vagina_core.dart';
import 'package:vagina_assistant_model/vagina_assistant_model.dart';

/// API Provider type enum
enum ApiProviderType {
  azureOpenAI,
}

/// API Provider type state provider
final apiProviderTypeProvider = StateProvider<ApiProviderType>((ref) => ApiProviderType.azureOpenAI);

/// Settings screen for API configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _deploymentController = TextEditingController();
  bool _isApiKeyVisible = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final apiKey = await storage.getApiKey();
      final endpoint = await storage.getAzureEndpoint();
      final deployment = await storage.getAzureDeployment();
      
      if (apiKey != null) {
        _apiKeyController.text = apiKey;
      }
      if (endpoint != null) {
        _endpointController.text = endpoint;
      }
      if (deployment != null) {
        _deploymentController.text = deployment;
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
    if (_apiKeyController.text.trim().isEmpty) {
      _showError('API Key is required');
      return;
    }
    if (_endpointController.text.trim().isEmpty) {
      _showError('Azure Endpoint is required');
      return;
    }
    if (_deploymentController.text.trim().isEmpty) {
      _showError('Deployment Name is required');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveApiKey(_apiKeyController.text.trim());
      await storage.saveAzureEndpoint(_endpointController.text.trim());
      await storage.saveAzureDeployment(_deploymentController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
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

  Future<void> _deleteSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete All Settings?'),
        content: const Text(
          'Are you sure you want to delete all saved API settings?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final storage = ref.read(secureStorageServiceProvider);
        await storage.deleteApiKey();
        await storage.deleteAzureEndpoint();
        await storage.deleteAzureDeployment();
        _apiKeyController.clear();
        _endpointController.clear();
        _deploymentController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings deleted'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      } catch (e) {
        _showError('Failed to delete settings: $e');
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    _deploymentController.dispose();
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
                title: const Text('Settings'),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Error message banner
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

                    // Azure OpenAI Configuration Section
                    _buildSectionHeader('Azure OpenAI Configuration'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Azure Endpoint
                          const Text(
                            'Azure Endpoint',
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
                              controller: _endpointController,
                              decoration: const InputDecoration(
                                hintText: 'https://your-resource.openai.azure.com',
                              ),
                              keyboardType: TextInputType.url,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Example: https://your-resource.openai.azure.com',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Deployment Name
                          const Text(
                            'Deployment Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!_isLoading)
                            TextField(
                              controller: _deploymentController,
                              decoration: const InputDecoration(
                                hintText: 'gpt-4o-realtime-preview',
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'The deployment name of your Azure OpenAI model',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // API Key
                          const Text(
                            'API Key',
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
                                hintText: 'Enter your Azure OpenAI API key',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
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
                                    if (_apiKeyController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: AppTheme.errorColor,
                                        onPressed: _deleteSettings,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveSettings,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save Settings'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your credentials are stored securely on your device and never sent to our servers.',
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
                    _buildSectionHeader('Voice Settings'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assistant Voice',
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
                                style:
                                    const TextStyle(color: AppTheme.textPrimary),
                              ),
                              activeColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // About Section
                    _buildSectionHeader('About'),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('App Version', '1.0.0'),
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
