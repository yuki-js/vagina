import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/announcement/services/announcement_service.dart';
import 'package:vagina/feat/announcement/widgets/home_announcement_host.dart';
import 'package:vagina/feat/home/tabs/agents.dart';
import 'package:vagina/feat/home/tabs/more.dart';
import 'package:vagina/feat/home/tabs/sessions.dart';
import 'package:vagina/feat/home/tabs/speed_dial.dart';
import 'package:vagina/feat/settings/screens/settings.dart';
import 'package:vagina/feat/speed_dial/screens/config.dart';
import 'package:vagina/feat/text_agents/screens/agent_form_screen.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/utils/call_navigation_utils.dart';

/// Main home screen with tab bar for phone app design
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTabIndex = 0;

  late final PageController _pageController;
  late final AnnouncementService _announcementService;

  List<_TabInfo> _buildTabs(AppLocalizations l10n) {
    return [
      _TabInfo(
        icon: Icons.star,
        label: l10n.homeTabSpeedDial,
        canAdd: true,
      ),
      _TabInfo(
        icon: Icons.history,
        label: l10n.homeTabSessions,
        canAdd: false,
      ),
      _TabInfo(
        icon: Icons.contacts,
        label: l10n.homeTabAgents,
        canAdd: true,
      ),
      _TabInfo(
        icon: Icons.apps,
        label: l10n.homeTabMore,
        canAdd: false,
      ),
    ];
  }

  static final List<Widget> _pages = [
    const SpeedDialTab(),
    const SessionsTab(),
    const AgentsTab(),
    const MoreTab(),
  ];

  // Reserve the middle slot in BottomNavigationBar for the FAB.
  static const int _fabNavIndex = 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTabIndex);
    _announcementService = AnnouncementService(
      preferencesRepository: ref.read(preferencesRepositoryProvider),
    );
  }

  @override
  void dispose() {
    _announcementService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _handleAddButton() async {
    // Context-sensitive add button based on current tab
    final l10n = AppLocalizations.of(context);
    final tab = _buildTabs(l10n)[_currentTabIndex];
    if (!tab.canAdd) return;

    switch (_currentTabIndex) {
      case 0:
        // Speed dial tab
        await _addSpeedDial();
        break;
      case 2:
        // Agents tab
        await _addTextAgent();
        break;
    }
  }

  Future<void> _addSpeedDial() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SpeedDialConfigScreen(),
      ),
    );
  }

  Future<void> _addTextAgent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AgentFormScreen(),
      ),
    );
  }

  Future<void> _handleCallButton() async {
    await CallNavigationUtils.navigateToCallWithDefault(
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = _buildTabs(l10n);
    final currentTab = tabs[_currentTabIndex];

    return Scaffold(
      body: Column(
        children: [
          // App bar
          Container(
            color: AppTheme.lightBackgroundStart,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Title and action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Spacer(),
                        // Title
                        Text(
                          l10n.appTitle(AppConfig.appName),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            letterSpacing: 4,
                          ),
                        ),
                        const Spacer(),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Add button (context-sensitive)
                            if (currentTab.canAdd)
                              IconButton(
                                icon: const Icon(Icons.add),
                                color: AppTheme.lightTextPrimary,
                                onPressed: _handleAddButton,
                              ),
                            const SizedBox(width: 8),
                            // Settings button (cog icon)
                            IconButton(
                              icon: const Icon(Icons.settings),
                              color: AppTheme.lightTextPrimary,
                              onPressed: _openSettings,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const HomeAnnouncementHostPlaceholder(),
          // Tab content (swipeable)
          Expanded(
            child: Container(
              color: AppTheme.lightBackgroundStart,
              child: SafeArea(
                top: false,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentTabIndex = index;
                    });
                  },
                  children: _pages,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex >= _fabNavIndex
            ? _currentTabIndex + 1
            : _currentTabIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.lightSurfaceColor,
        elevation: 8,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.lightTextSecondary,
        onTap: (navIndex) {
          // Center slot is reserved for the call FAB.
          if (navIndex == _fabNavIndex) return;

          final tabIndex = navIndex > _fabNavIndex ? navIndex - 1 : navIndex;
          setState(() {
            _currentTabIndex = tabIndex;
          });
          _pageController.animateToPage(
            tabIndex,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(tabs[0].icon),
            label: tabs[0].label,
          ),
          BottomNavigationBarItem(
            icon: Icon(tabs[1].icon),
            label: tabs[1].label,
          ),
          const BottomNavigationBarItem(
            icon: SizedBox.shrink(),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(tabs[2].icon),
            label: tabs[2].label,
          ),
          BottomNavigationBarItem(
            icon: Icon(tabs[3].icon),
            label: tabs[3].label,
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
          heroTag: 'call_fab',
          shape: const CircleBorder(),
          onPressed: _handleCallButton,
          backgroundColor: AppTheme.successColor,
          elevation: 6,
          child: const Icon(
            Icons.phone,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class HomeAnnouncementHostPlaceholder extends StatelessWidget {
  const HomeAnnouncementHostPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    final service = state?._announcementService;
    if (service == null) {
      return const SizedBox.shrink();
    }

    return HomeAnnouncementHost(service: service);
  }
}

class _TabInfo {
  final IconData icon;
  final String label;
  final bool canAdd; // Whether this tab supports the add button

  const _TabInfo({
    required this.icon,
    required this.label,
    required this.canAdd,
  });
}
