import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import 'agents_providers.dart';
import '../../models/text_agent.dart';

/// Agents tab - Text agent selection and management
class AgentsTab extends ConsumerWidget {
  const AgentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableAgents = ref.watch(availableTextAgentsProvider);
    final selectedAgentId = ref.watch(selectedTextAgentIdProvider);

    return Container(
      decoration: AppTheme.lightBackgroundGradient,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'テキストエージェント',
                style: TextStyle(
                  color: AppTheme.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.lightPrimary.withValues(alpha: 0.1),
                      AppTheme.lightSecondary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (availableAgents.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  '利用可能なエージェントがありません',
                  style: TextStyle(
                    color: AppTheme.lightTextSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final agent = availableAgents[index];
                    final isSelected = agent.id == selectedAgentId;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AgentCard(
                        agent: agent,
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(selectedTextAgentIdProvider.notifier).select(agent.id);
                        },
                      ),
                    );
                  },
                  childCount: availableAgents.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final TextAgent agent;
  final bool isSelected;
  final VoidCallback onTap;

  const _AgentCard({
    required this.agent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.lightPrimary.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.lightPrimary
                  : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      agent.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppTheme.lightPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '選択中',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                agent.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              if (agent.capabilities.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: agent.capabilities.map((capability) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSecondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        capability,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.lightTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.computer,
                    size: 14,
                    color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    agent.modelIdentifier,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
