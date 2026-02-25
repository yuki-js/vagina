import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/feat/text_agents/ui/screens/agent_form_screen.dart';

/// Agents tab - Text agent management
class AgentsTab extends ConsumerWidget {
  const AgentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(textAgentsProvider);

    return agentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('エラー: $error'),
      ),
      data: (agents) {
        if (agents.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'テキストエージェント',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'テキスト処理用のエージェントを管理',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // Agent grid with fixed-size cards
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate number of columns based on screen width
                // Each card should be approximately 160px wide
                final cardWidth = 160.0;
                final crossAxisCount =
                    (constraints.maxWidth / cardWidth).floor().clamp(2, 6);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: agents.length,
                  itemBuilder: (context, index) {
                    final agent = agents[index];
                    return _buildAgentCard(context, ref, agent);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'テキストエージェント',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'テキスト処理用のエージェントを管理',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 64,
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'エージェントがまだありません',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '右上の + ボタンで追加できます',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentCard(
    BuildContext context,
    WidgetRef ref,
    TextAgent agent,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _viewAgent(context, agent),
        onLongPress: () => _editAgent(context, agent),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Icon(
                Icons.smart_toy,
                size: 48,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                agent.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightTextPrimary,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Provider
              Text(
                agent.config.provider.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewAgent(
    BuildContext context,
    TextAgent agent,
  ) async {
    // Placeholder for view agent action
    // Could show agent details, chat, or other functionality
  }

  Future<void> _editAgent(
    BuildContext context,
    TextAgent agent,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AgentFormScreen(
          agent: agent,
        ),
      ),
    );
  }
}
