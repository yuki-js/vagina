import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../components/title_bar.dart';
import '../../components/emoji_picker.dart';
import '../../providers/providers.dart';
import '../../models/speed_dial.dart';
import '../settings_screen.dart';
import '../about_screen.dart';
import '../call/call_screen.dart';
import 'speed_dial_tab.dart';
import 'sessions_tab.dart';
import 'tools_tab.dart';
import 'agents_tab.dart';

/// Main home screen with tab bar for phone app design
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTabIndex = 0;

  late final PageController _pageController;

  // Tab definitions
  final List<_TabInfo> _tabs = const [
    _TabInfo(
      icon: Icons.star,
      label: 'スピードダイヤル',
      canAdd: true,
    ),
    _TabInfo(
      icon: Icons.history,
      label: 'セッション',
      canAdd: false,
    ),
    _TabInfo(
      icon: Icons.build, // Using build (wrench-like) instead of cog
      label: 'ツール',
      canAdd: false,
    ),
    _TabInfo(
      icon: Icons.person,
      label: 'エージェント',
      canAdd: false,
    ),
  ];

  static const List<Widget> _pages = [
    SpeedDialTab(),
    SessionsTab(),
    ToolsTab(),
    AgentsTab(),
  ];

  // Reserve the middle slot in BottomNavigationBar for the FAB.
  static const int _fabNavIndex = 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AboutScreen()),
    );
  }

  Future<void> _handleAddButton() async {
    // Context-sensitive add button based on current tab
    final tab = _tabs[_currentTabIndex];
    if (!tab.canAdd) return;

    if (_currentTabIndex == 0) {
      // Speed dial tab
      await _addSpeedDial();
    }
  }

  Future<void> _addSpeedDial() async {
    String? selectedEmoji;

    // Show emoji picker first
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: EmojiPicker(
            selectedEmoji: selectedEmoji,
            onEmojiSelected: (emoji) {
              selectedEmoji = emoji;
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );

    if (selectedEmoji == null || !mounted) return;

    // Then show the main form dialog
    final formKey = GlobalKey<FormState>();
    String name = '';
    String systemPrompt = '';
    String voice = 'alloy';
    final iconEmoji = selectedEmoji!;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(iconEmoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            const Text('スピードダイヤルを追加'),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '名前',
                    hintText: '例: アシスタント',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '名前を入力してください';
                    }
                    return null;
                  },
                  onSaved: (value) => name = value!,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'システムプロンプト',
                    hintText: '例: あなたは親切なアシスタントです',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'システムプロンプトを入力してください';
                    }
                    return null;
                  },
                  onSaved: (value) => systemPrompt = value!,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '音声',
                  ),
                  initialValue: voice,
                  items: const [
                    DropdownMenuItem(value: 'alloy', child: Text('Alloy')),
                    DropdownMenuItem(value: 'echo', child: Text('Echo')),
                    DropdownMenuItem(value: 'shimmer', child: Text('Shimmer')),
                  ],
                  onChanged: (value) => voice = value ?? 'alloy',
                  onSaved: (value) => voice = value ?? 'alloy',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final speedDial = SpeedDial(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        systemPrompt: systemPrompt,
        voice: voice,
        iconEmoji: iconEmoji,
        createdAt: DateTime.now(),
      );

      final storage = ref.read(storageServiceProvider);
      await storage.saveSpeedDial(speedDial);

      // Refresh the speed dials list
      ref.invalidate(refreshableSpeedDialsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('スピードダイヤルを追加しました')),
        );
      }
    }
  }

  Future<void> _handleCallButton() async {
    // Navigate to call screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CallScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = _tabs[_currentTabIndex];

    return Scaffold(
      body: Column(
        children: [
          // Custom title bar for desktop
          const CustomTitleBar(),
          // App bar
          Container(
            decoration: AppTheme.lightBackgroundGradient,
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
                        // Title with easter egg
                        GestureDetector(
                          onTap: _openAbout,
                          child: const Text(
                            'VAGINA',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              letterSpacing: 4,
                            ),
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
          // Tab content (swipeable)
          Expanded(
            child: Container(
              decoration: AppTheme.lightBackgroundGradient,
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
            icon: Icon(_tabs[0].icon),
            label: _tabs[0].label,
          ),
          BottomNavigationBarItem(
            icon: Icon(_tabs[1].icon),
            label: _tabs[1].label,
          ),
          const BottomNavigationBarItem(
            icon: SizedBox.shrink(),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_tabs[2].icon),
            label: _tabs[2].label,
          ),
          BottomNavigationBarItem(
            icon: Icon(_tabs[3].icon),
            label: _tabs[3].label,
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
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
