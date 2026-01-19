import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/text_agents/model/text_agent.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/feat/text_agents/ui/widgets/agent_card.dart';
import 'package:vagina/feat/text_agents/ui/widgets/agent_list_tile.dart';
import 'package:vagina/feat/text_agents/ui/widgets/empty_agents_view.dart';
import 'package:vagina/feat/text_agents/ui/screens/agent_form_screen.dart';
import 'package:vagina/core/state/repository_providers.dart';

/// Main agents screen displaying list of text agents
class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  bool _isGridView = true;

  Future<void> _navigateToAgentForm({TextAgent? agent}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AgentFormScreen(agent: agent),
      ),
    );
  }

  Future<void> _deleteAgent(TextAgent agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${agent.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
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
        final repo = ref.read(textAgentRepositoryProvider);
        
        // If deleted agent was selected, clear selection
        final selectedId = await ref.read(selectedTextAgentIdProvider.future);
        if (selectedId == agent.id) {
          await repo.setSelectedAgentId(null);
          ref.invalidate(selectedTextAgentIdProvider);
        }
        
        await repo.delete(agent.id);
        ref.invalidate(textAgentsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('エージェントを削除しました'),
              duration: Duration(seconds: 2),
            ),
          );
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

  Future<void> _selectAgent(TextAgent agent) async {
    try {
      await ref.read(textAgentRepositoryProvider).setSelectedAgentId(agent.id);
      ref.invalidate(selectedTextAgentIdProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${agent.name}」を選択しました'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('選択に失敗しました: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _refreshAgents() async {
    ref.invalidate(textAgentsProvider);
    await ref.read(textAgentsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(textAgentsProvider);
    final selectedIdAsync = ref.watch(selectedTextAgentIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: AppTheme.lightBackgroundGradient,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'テキストエージェント',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  // View toggle
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                    tooltip: _isGridView ? 'リスト表示' : 'グリッド表示',
                    color: AppTheme.lightTextSecondary,
                  ),
                  // Add agent button
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _navigateToAgentForm(),
                    tooltip: 'エージェントを追加',
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAgents,
                child: agentsAsync.when(
                  data: (agents) {
                    if (agents.isEmpty) {
                      return EmptyAgentsView(
                        onCreateAgent: () => _navigateToAgentForm(),
                      );
                    }

                    return selectedIdAsync.when(
                      data: (selectedId) {
                        if (_isGridView) {
                          return _buildGridView(agents, selectedId);
                        } else {
                          return _buildListView(agents, selectedId);
                        }
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
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppTheme.errorColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'エラーが発生しました',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.errorColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshAgents,
                            child: const Text('再試行'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAgentForm(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGridView(List<TextAgent> agents, String? selectedId) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        final agent = agents[index];
        final isSelected = agent.id == selectedId;

        return AgentCard(
          agent: agent,
          isSelected: isSelected,
          onTap: () => _selectAgent(agent),
          onEdit: () => _navigateToAgentForm(agent: agent),
          onDelete: () => _deleteAgent(agent),
        );
      },
    );
  }

  Widget _buildListView(List<TextAgent> agents, String? selectedId) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        final agent = agents[index];
        final isSelected = agent.id == selectedId;

        return AgentListTile(
          agent: agent,
          isSelected: isSelected,
          onTap: () => _selectAgent(agent),
          onEdit: () => _navigateToAgentForm(agent: agent),
          onDelete: () => _deleteAgent(agent),
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) {
      return 4;
    } else if (width > 800) {
      return 3;
    } else if (width > 600) {
      return 2;
    } else {
      return 1;
    }
  }
}
