import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/callv2/models/text_agent_api_config.dart';
import 'package:vagina/feat/callv2/models/text_agent_info.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/feat/text_agents/ui/screens/agent_form_screen.dart';

/// Agents tab - Text agent management with phone book interface
class AgentsTab extends ConsumerStatefulWidget {
  const AgentsTab({super.key});

  @override
  ConsumerState<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends ConsumerState<AgentsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

        // Filter agents based on search query
        final filteredAgents = _searchQuery.isEmpty
            ? agents
            : agents.where((agent) {
                final query = _searchQuery.toLowerCase();
                return agent.name.toLowerCase().contains(query) ||
                    agent.description.toLowerCase().contains(query);
              }).toList();

        return Column(
          children: [
            // Search bar
            _buildSearchBar(),
            // Agent list
            Expanded(
              child: filteredAgents.isEmpty
                  ? _buildNoResultsState()
                  : _buildAgentList(filteredAgents),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'エージェントを検索...',
          hintStyle: TextStyle(
            color: AppTheme.lightTextSecondary,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.lightTextSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppTheme.lightTextSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildAgentList(List<TextAgentInfo> agents) {
    return ListView.builder(
      itemCount: agents.length,
      itemBuilder: (context, index) {
        return _buildAgentListTile(agents[index]);
      },
    );
  }

  Widget _buildAgentListTile(TextAgentInfo agent) {
    // Generate a color based on agent name for avatar
    final colorIndex =
        agent.name.codeUnits.isNotEmpty ? agent.name.codeUnits.first % 10 : 0;
    final avatarColor = _getAvatarColor(colorIndex);
    final initial = agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 0.5,
          ),
        ),
        color: Colors.white,
      ),
      child: ListTile(
        enableFeedback: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: avatarColor.withValues(alpha: 0.2),
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: avatarColor,
            ),
          ),
        ),
        title: Text(
          agent.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          _getProviderDisplayString(agent),
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppTheme.lightTextSecondary,
        ),
        onTap: () => _editAgent(context, agent),
      ),
    );
  }

  Color _getAvatarColor(int index) {
    final colors = [
      AppTheme.primaryColor,
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF009688), // Teal
    ];
    return colors[index % colors.length];
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 80,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'エージェントがありません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
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
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '検索結果がありません',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getProviderDisplayString(TextAgentInfo agent) {
    final apiConfig = agent.apiConfig;
    if (apiConfig is SelfhostedTextAgentApiConfig) {
      return '${apiConfig.provider}: ${apiConfig.model}';
    } else if (apiConfig is HostedTextAgentApiConfig) {
      return 'Hosted: ${apiConfig.modelId}';
    }
    return 'Unknown';
  }

  Future<void> _editAgent(
    BuildContext context,
    TextAgentInfo agent,
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
