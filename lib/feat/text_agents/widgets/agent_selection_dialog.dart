import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/models/text_agent_api_config.dart';
import 'package:vagina/feat/call/models/text_agent_info.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Dialog for quickly selecting a text agent
class AgentSelectionDialog extends ConsumerWidget {
  const AgentSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final agentsAsync = ref.watch(textAgentsProvider);
    final selectedIdAsync = ref.watch(selectedTextAgentIdProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    l10n.textAgentsSelectionDialogTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppTheme.lightTextSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Agent list
            Flexible(
              child: agentsAsync.when(
                data: (agents) {
                  if (agents.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.smart_toy_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.textAgentsSelectionDialogEmptyTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return selectedIdAsync.when(
                    data: (selectedId) {
                      return ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: agents.length,
                        itemBuilder: (context, index) {
                          final agent = agents[index];
                          final isSelected = agent.id == selectedId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: isSelected ? 2 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                              onTap: () async {
                                await ref
                                    .read(configRepositoryProvider)
                                    .setSelectedTextAgentId(agent.id);
                                ref.invalidate(selectedTextAgentIdProvider);
                                if (context.mounted) {
                                  Navigator.of(context).pop(agent);
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Selection indicator
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: null,
                                      activeColor: AppTheme.primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Agent icon
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                                .withValues(alpha: 0.15)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.smart_toy,
                                        size: 20,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Agent info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            agent.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: AppTheme.lightTextPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _getProviderDisplayString(
                                              context,
                                              agent,
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppTheme.lightTextSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Text(
                        l10n.textAgentsSelectionDialogError(error.toString()),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      l10n.textAgentsSelectionDialogError(error.toString()),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
