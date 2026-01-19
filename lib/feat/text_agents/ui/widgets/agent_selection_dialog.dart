import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/core/state/repository_providers.dart';

/// Dialog for quickly selecting a text agent
class AgentSelectionDialog extends ConsumerWidget {
  const AgentSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  const Text(
                    'エージェントを選択',
                    style: TextStyle(
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
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.smart_toy_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'エージェントがありません',
                            style: TextStyle(
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
                                    .read(textAgentRepositoryProvider)
                                    .setSelectedAgentId(agent.id);
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
                                    Radio<bool>(
                                      value: true,
                                      groupValue: isSelected,
                                      onChanged: null,
                                      activeColor: AppTheme.primaryColor,
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
                                            agent.config.getDisplayString(),
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
                      child: Text('エラー: $error'),
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
                    child: Text('エラー: $error'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
