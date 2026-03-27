import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/shared/widgets/tool_config_section.dart';
import 'package:vagina/feat/text_agents/model/text_agent_config.dart';
import 'package:vagina/feat/text_agents/model/text_agent_provider.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/feat/text_agents/util/provider_parser.dart';

/// Screen for creating or editing a text agent with simplified multi-provider support
///
/// Configuration fields:
/// 1. Agent Name
/// 2. Description (for list_available_agents)
/// 3. System Prompt
/// 4. Provider (OpenAI, Azure, LiteLLM, Custom)
/// 5. API Endpoint / Model (depends on provider)
/// 6. API Key
class AgentFormScreen extends ConsumerStatefulWidget {
  final TextAgentInfo? agent; // null for new agent

  const AgentFormScreen({
    super.key,
    this.agent,
  });

  @override
  ConsumerState<AgentFormScreen> createState() => _AgentFormScreenState();
}

class _AgentFormScreenState extends ConsumerState<AgentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _promptController;
  late TextEditingController _apiKeyController;
  late TextEditingController _apiEndpointController;
  late TextAgentProvider _provider;
  late Map<String, bool> _enabledTools;
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
      _apiKeyController = TextEditingController();
      _apiEndpointController = TextEditingController();
      _provider = TextAgentProvider.azure;
      _enabledTools = {};
    } else {
      final agent = widget.agent!;
      _nameController = TextEditingController(text: agent.name);
      _descriptionController = TextEditingController(text: agent.description);
      _promptController = TextEditingController(text: agent.prompt);
      
      final apiConfig = agent.apiConfig;
      if (apiConfig is SelfhostedTextAgentApiConfig) {
        _apiKeyController = TextEditingController(text: apiConfig.apiKey);
        _apiEndpointController = TextEditingController(text: apiConfig.baseUrl);
        _provider = TextAgentProvider.fromString(apiConfig.provider);
      } else {
        // Fallback for hosted config (should not happen in current implementation)
        _apiKeyController = TextEditingController();
        _apiEndpointController = TextEditingController();
        _provider = TextAgentProvider.azure;
      }
      
      _enabledTools = Map<String, bool>.from(agent.enabledTools);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    _apiKeyController.dispose();
    _apiEndpointController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldNameを入力してください';
    }
    return null;
  }

  String? _validateEndpoint(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'エンドポイント/モデルを入力してください';
    }

    // For OpenAI, just check it's not empty (it's a model name)
    if (_provider == TextAgentProvider.openai) {
      return null;
    }

    // For other providers, validate as URL
    return ProviderParser.validateUrl(value.trim(), _provider);
  }

  Future<void> _saveAgent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final endpoint = _apiEndpointController.text.trim();
      final modelIdentifier = _extractModelIdentifier(_provider, endpoint);
      
      final apiConfig = SelfhostedTextAgentApiConfig(
        provider: _provider.value,
        baseUrl: endpoint,
        apiKey: _apiKeyController.text.trim(),
        model: modelIdentifier,
      );

      final now = DateTime.now();
      final agent = TextAgentInfo(
        id: _isNewAgent ? 'ta_${now.millisecondsSinceEpoch}' : widget.agent!.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        prompt: _promptController.text.trim(),
        apiConfig: apiConfig,
        enabledTools: _enabledTools,
      );

      final configRepository = ref.read(configRepositoryProvider);
      await configRepository.saveTextAgent(agent);

      if (mounted) {
        ref.invalidate(textAgentsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNewAgent ? 'エージェントを作成しました' : 'エージェントを更新しました',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
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
      builder: (context) => AlertDialog(
        title: const Text('エージェントを削除'),
        content: Text('「${widget.agent!.name}」を削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final configRepository = ref.read(configRepositoryProvider);
        await configRepository.deleteTextAgent(widget.agent!.id);
        ref.invalidate(textAgentsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('エージェントを削除しました'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('削除に失敗しました: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  String _extractModelIdentifier(TextAgentProvider provider, String endpoint) {
    switch (provider) {
      case TextAgentProvider.openai:
        // For OpenAI, endpoint is actually the model name
        return endpoint;
      case TextAgentProvider.azure:
        // Try to extract deployment from URL
        final deployment =
            TextAgentConfig.tryExtractAzureDeploymentFromUrl(endpoint);
        return deployment ?? 'unknown-deployment';
      case TextAgentProvider.litellm:
      case TextAgentProvider.custom:
        // For proxy endpoints, we don't know the model from URL
        return 'default';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isNewAgent ? 'エージェントを追加' : 'エージェントを編集'),
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
              onPressed: _saveAgent,
              tooltip: '保存',
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
              _buildSectionHeader('基本情報'),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'エージェント名 *',
                        hintText: '例: リサーチアシスタント',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) => _validateRequired(value, 'エージェント名'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: '説明 (オプション)',
                        hintText: '例: 詳細な分析とサマリーを提供するエージェント',
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
                        labelText: 'System Prompt (オプション)',
                        hintText: '例: You are a helpful research assistant...',
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

              // Provider Configuration Section
              _buildSectionHeader('設定'),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    // Provider Selection
                    DropdownButtonFormField<TextAgentProvider>(
                      initialValue: _provider,
                      decoration: InputDecoration(
                        labelText: 'プロバイダー *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(Icons.cloud),
                      ),
                      items: TextAgentProvider.values.map((provider) {
                        return DropdownMenuItem(
                          value: provider,
                          child: Text(provider.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _provider = value;
                            // Clear endpoint when provider changes
                            _apiEndpointController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Help text for current provider
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ProviderParser.getProviderHelpText(_provider),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // API Endpoint / Model field (labeled based on provider)
                    TextFormField(
                      controller: _apiEndpointController,
                      decoration: InputDecoration(
                        labelText: _getEndpointLabel(),
                        hintText: ProviderParser.getExampleUrl(_provider),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: _provider == TextAgentProvider.openai
                            ? const Icon(Icons.precision_manufacturing)
                            : const Icon(Icons.link),
                      ),
                      validator: _validateEndpoint,
                      keyboardType: _provider == TextAgentProvider.openai
                          ? TextInputType.text
                          : TextInputType.url,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // API Key field
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: 'APIキー *',
                        hintText: 'プロバイダーのAPIキーを入力',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(Icons.key),
                      ),
                      validator: (value) => _validateRequired(value, 'APIキー'),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tool Configuration Section
              _buildSectionHeader('ツール設定'),
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
                onPressed: _isSaving ? null : _saveAgent,
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isNewAgent ? '作成' : '保存',
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

  String _getEndpointLabel() {
    switch (_provider) {
      case TextAgentProvider.openai:
        return 'モデル *';
      case TextAgentProvider.azure:
        return 'エンドポイント *';
      case TextAgentProvider.litellm:
        return 'プロキシURL *';
      case TextAgentProvider.custom:
        return 'エンドポイントURL *';
    }
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
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
