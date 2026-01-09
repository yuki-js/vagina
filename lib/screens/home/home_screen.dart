import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../components/title_bar.dart';
import '../../components/call_button.dart';
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
    final formKey = GlobalKey<FormState>();
    String name = '';
    String systemPrompt = '';
    String voice = 'alloy';
    String iconEmoji = '⭐';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スピードダイヤルを追加'),
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
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'アイコン絵文字',
                    hintText: '例: ⭐',
                  ),
                  initialValue: iconEmoji,
                  onSaved: (value) => iconEmoji = value ?? '⭐',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // Tab content
          Expanded(
            child: Container(
              decoration: AppTheme.lightBackgroundGradient,
              child: SafeArea(
                top: false,
                child: _buildTabContent(),
              ),
            ),
          ),
          // Bottom navigation with call button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.lightSurfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Green circular call button (special design)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: CallButton(
                      isCallActive: false,
                      size: 64,
                      onPressed: _handleCallButton,
                    ),
                  ),
                  // Tab bar
                  Row(
                    children: List.generate(_tabs.length, (index) {
                      final tab = _tabs[index];
                      final isSelected = _currentTabIndex == index;
                      return Expanded(
                        child: _buildTabButton(
                          icon: tab.icon,
                          label: tab.label,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _currentTabIndex = index;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTabIndex) {
      case 0:
        return const SpeedDialTab();
      case 1:
        return const SessionsTab();
      case 2:
        return const ToolsTab();
      case 3:
        return const AgentsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.lightTextSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppTheme.primaryColor : AppTheme.lightTextSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
