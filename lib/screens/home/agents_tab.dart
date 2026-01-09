import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../agent_config_screen.dart';

/// Agent definition for the list
class _AgentDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _AgentDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Agents tab - shows available agents list
/// Tap to navigate to agent configuration screen
class AgentsTab extends ConsumerWidget {
  const AgentsTab({super.key});

  // Define available agents
  static const _agents = [
    _AgentDef(
      id: 'default',
      name: 'デフォルトアシスタント',
      description: '標準的なAI会話アシスタント',
      icon: Icons.assistant,
      color: AppTheme.primaryColor,
    ),
    _AgentDef(
      id: 'creative',
      name: 'クリエイティブアシスタント',
      description: '創造的なアイデア生成に特化（準備中）',
      icon: Icons.lightbulb_outline,
      color: Colors.amber,
    ),
    _AgentDef(
      id: 'technical',
      name: 'テクニカルアシスタント',
      description: '技術的な質問や問題解決に特化（準備中）',
      icon: Icons.code,
      color: Colors.green,
    ),
    _AgentDef(
      id: 'casual',
      name: 'カジュアルアシスタント',
      description: '気軽な雑談や日常会話に特化（準備中）',
      icon: Icons.chat_bubble_outline,
      color: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantConfig = ref.watch(assistantConfigProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'エージェント',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'エージェントを選択して設定を変更',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
        // Current agent info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '現在のエージェント',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assistantConfig.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.lightTextPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Agents list
        ..._agents.map((agent) => _buildAgentCard(context, agent)),
      ],
    );
  }

  Widget _buildAgentCard(BuildContext context, _AgentDef agent) {
    final isComingSoon = agent.id != 'default';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isComingSoon
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AgentConfigScreen(
                      agentId: agent.id,
                      agentName: agent.name,
                    ),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isComingSoon ? Colors.grey : agent.color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  agent.icon,
                  color: isComingSoon ? Colors.grey : agent.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isComingSoon ? Colors.grey : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      agent.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isComingSoon ? Colors.grey : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isComingSoon ? Colors.grey : AppTheme.lightTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
