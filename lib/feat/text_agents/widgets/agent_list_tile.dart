import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// List tile widget for displaying a text agent in compact view
class AgentListTile extends StatelessWidget {
  final TextAgentInfo agent;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AgentListTile({
    super.key,
    required this.agent,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: isSelected ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              )
            : BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Agent icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.smart_toy,
                  size: 24,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              // Agent info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            agent.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: AppTheme.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.textAgentsSelectedBadge,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            agent.description.isNotEmpty
                                ? agent.description
                                : _getProviderDisplayString(context, agent),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEdit,
                color: AppTheme.lightTextSecondary,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18),
                onPressed: onDelete,
                color: AppTheme.errorColor,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getProviderDisplayString(BuildContext context, TextAgentInfo agent) {
    final l10n = AppLocalizations.of(context);
    final apiConfig = agent.apiConfig;
    if (apiConfig is SelfhostedTextAgentApiConfig) {
      return '${_getProviderLabel(apiConfig.provider, l10n)}: ${apiConfig.model}';
    } else if (apiConfig is HostedTextAgentApiConfig) {
      return '${l10n.textAgentsProviderHostedPrefix}: ${apiConfig.modelId}';
    }
    return l10n.textAgentsProviderUnknown;
  }

  String _getProviderLabel(String providerValue, AppLocalizations l10n) {
    switch (providerValue) {
      case 'openai':
        return l10n.textAgentsProviderLabelOpenAi;
      case 'azure':
        return l10n.textAgentsProviderLabelAzure;
      case 'litellm':
        return l10n.textAgentsProviderLabelLiteLlm;
      case 'custom':
        return l10n.textAgentsProviderLabelCustom;
      default:
        return providerValue;
    }
  }
}
