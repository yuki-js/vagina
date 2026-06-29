import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/text_agents/screens/agent_form_screen.dart';
import 'package:vagina/feat/text_agents/state/text_agent_providers.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/text_agent_definition.dart';
import 'package:vagina/models/text_agent_model_preset.dart';

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
    final l10n = AppLocalizations.of(context);
    final agentsAsync = ref.watch(textAgentsProvider);
    final modelPresetsAsync = ref.watch(textAgentModelsProvider);

    return agentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.textAgentsLoadError(error.toString()))),
      data: (agents) {
        if (agents.isEmpty) {
          return _buildTabPanel(_buildEmptyState(context));
        }

        // Filter agents based on search query
        final filteredAgents = _searchQuery.isEmpty
            ? agents
            : agents.where((agent) {
                final query = _searchQuery.toLowerCase();
                return agent.name.toLowerCase().contains(query) ||
                    (agent.description ?? '').toLowerCase().contains(query) ||
                    agent.textModelId.toLowerCase().contains(query);
              }).toList();

        return _buildTabPanel(
          Column(
            children: [
              // Search bar
              _buildSearchBar(),
              // Agent list
              Expanded(
                child: filteredAgents.isEmpty
                    ? _buildNoResultsState()
                    : _buildAgentList(filteredAgents, modelPresetsAsync),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final l10n = AppLocalizations.of(context);

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
          hintText: l10n.textAgentsSearchHint,
          hintStyle: TextStyle(
            color: AppTheme.lightTextSecondary,
            fontSize: 16,
          ),
          prefixIcon: Icon(Icons.search, color: AppTheme.lightTextSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppTheme.lightTextSecondary),
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

  Widget _buildAgentList(
    List<TextAgentDefinition> agents,
    AsyncValue<List<TextAgentModelPreset>> modelPresetsAsync,
  ) {
    final modelPresetsById = modelPresetsAsync.maybeWhen(
      data: (presets) => {for (final preset in presets) preset.id: preset},
      orElse: () => const <String, TextAgentModelPreset>{},
    );

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        return _buildAgentListTile(agents[index], modelPresetsById);
      },
    );
  }

  Widget _buildAgentListTile(
    TextAgentDefinition agent,
    Map<String, TextAgentModelPreset> modelPresetsById,
  ) {
    // Generate a color based on agent name for avatar
    final colorIndex = agent.name.codeUnits.isNotEmpty
        ? agent.name.codeUnits.first % 10
        : 0;
    final avatarColor = _getAvatarColor(colorIndex);
    final initial = agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?';

    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
        ),
        child: ListTile(
          enableFeedback: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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
            _getModelDisplayString(agent, modelPresetsById),
            style: TextStyle(fontSize: 14, color: AppTheme.lightTextSecondary),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: AppTheme.lightTextSecondary,
          ),
          onTap: () => _editAgent(context, agent),
        ),
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
    final l10n = AppLocalizations.of(context);

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
            l10n.textAgentsListEmptyTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.textAgentsListEmptyBody,
            style: TextStyle(fontSize: 14, color: AppTheme.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    final l10n = AppLocalizations.of(context);

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
            l10n.textAgentsSearchEmptyTitle,
            style: TextStyle(fontSize: 16, color: AppTheme.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPanel(Widget child) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            left: false,
            child: FloatingActionButton(
              heroTag: 'agents_add_fab',
              shape: const CircleBorder(),
              onPressed: () => _addAgent(context),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  String _getModelDisplayString(
    TextAgentDefinition agent,
    Map<String, TextAgentModelPreset> modelPresetsById,
  ) {
    final preset = modelPresetsById[agent.textModelId];
    if (preset != null) {
      return preset.displayName;
    }
    return agent.textModelId;
  }

  Future<void> _addAgent(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AgentFormScreen()));
  }

  Future<void> _editAgent(
    BuildContext context,
    TextAgentDefinition agent,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => AgentFormScreen(agent: agent)),
    );
  }
}
