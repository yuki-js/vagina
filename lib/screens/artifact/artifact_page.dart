import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import 'artifact_content_renderer.dart';
import 'widgets/widgets.dart';

/// Artifact page widget - displays artifact tabs and their content
class ArtifactPage extends ConsumerStatefulWidget {
  final VoidCallback onBackPressed;

  const ArtifactPage({
    super.key,
    required this.onBackPressed,
  });

  @override
  ConsumerState<ArtifactPage> createState() => _ArtifactPageState();
}

class _ArtifactPageState extends ConsumerState<ArtifactPage> {
  @override
  Widget build(BuildContext context) {
    final tabsAsync = ref.watch(artifactTabsProvider);
    final selectedTabIdAsync = ref.watch(selectedArtifactTabIdProvider);
    final artifactService = ref.read(artifactServiceProvider);

    return Column(
      children: [
        // Header
        ArtifactHeader(onBackPressed: widget.onBackPressed),

        // Tab bar (if tabs exist)
        tabsAsync.when(
          data: (tabs) {
            if (tabs.isEmpty) {
              return const SizedBox.shrink();
            }
            
            final selectedId = selectedTabIdAsync.value;
            return ArtifactTabBar(
              tabs: tabs,
              selectedTabId: selectedId,
              onTabSelected: (tabId) {
                artifactService.selectTab(tabId);
              },
              onTabClosed: (tabId) {
                artifactService.closeTab(tabId);
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Content area
        Expanded(
          child: tabsAsync.when(
            data: (tabs) {
              if (tabs.isEmpty) {
                return const ArtifactEmptyState();
              }
              
              final selectedId = selectedTabIdAsync.value;
              final selectedTab = selectedId != null 
                  ? tabs.where((t) => t.id == selectedId).firstOrNull
                  : null;
              
              if (selectedTab == null) {
                return const ArtifactEmptyState();
              }
              
              return ArtifactContentRenderer(
                tab: selectedTab,
                onContentChanged: (newContent) {
                  artifactService.updateTab(selectedTab.id, content: newContent);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            error: (_, __) => Center(
              child: Text(
                'アーティファクトの読み込みに失敗しました',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
