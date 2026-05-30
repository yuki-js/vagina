import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/repositories/repository_factory.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/announcement/services/announcement_service.dart';
import 'package:vagina/feat/announcement/widgets/home_announcement_host.dart';
import 'package:vagina/feat/home/tabs/agents.dart';
import 'package:vagina/feat/home/tabs/more.dart';
import 'package:vagina/feat/home/tabs/sessions.dart';
import 'package:vagina/feat/home/tabs/speed_dial.dart';
import 'package:vagina/feat/settings/screens/settings.dart';
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

  List<_TabInfo> _buildTabs() {
    final l10n = AppLocalizations.of(context);
    return [
      _TabInfo(
        icon: Icons.star,
        label: l10n.homeTabSpeedDial,
      ),
      _TabInfo(
        icon: Icons.history,
        label: l10n.homeTabSessions,
      ),
      _TabInfo(
        icon: Icons.contacts,
        label: l10n.homeTabAgents,
      ),
      _TabInfo(
        icon: Icons.apps,
        label: l10n.homeTabMore,
      ),
    ];
  }

  List<Widget> _buildPages() {
    return [
      const SpeedDialTab(),
      const SessionsTab(),
      const AgentsTab(),
      const MoreTab(),
    ];
  }

  // Reserve the middle slot in BottomNavigationBar for the FAB.
  static const int _fabNavIndex = 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTabIndex);
    _announcementService = AnnouncementService(
      preferencesRepository: RepositoryFactory.preferences,
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

  Future<void> _handleCallButton() async {
    await CallNavigationUtils.navigateToCallWithDefault(
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = _buildTabs();
    final pages = _buildPages();

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
                        IconButton(
                          icon: const Icon(Icons.settings),
                          color: AppTheme.lightTextPrimary,
                          onPressed: _openSettings,
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
                  children: pages,
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

  const _TabInfo({
    required this.icon,
    required this.label,
  });
}
