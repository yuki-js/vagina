import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import 'call/call_page.dart';
import 'chat/chat_page.dart';
import 'notepad/notepad_page.dart';
import 'settings_screen.dart';

/// Main home screen with PageView for swipe navigation between chat, call, and artifacts
/// Layout: Chat (left) -> Call (center) -> Artifacts (right)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Page indices for navigation (reversed order per requirements)
  /// Chat on left, Call in center, Artifacts on right
  static const int _chatPageIndex = 0;
  static const int _callPageIndex = 1;
  static const int _artifactPageIndex = 2;
  
  late final PageController _pageController;
  int _currentPageIndex = _callPageIndex;

  @override
  void initState() {
    super.initState();
    // Start on the call page (center)
    _pageController = PageController(initialPage: _callPageIndex);
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    if (_pageController.hasClients) {
      final page = _pageController.page?.round() ?? _callPageIndex;
      if (page != _currentPageIndex) {
        setState(() {
          _currentPageIndex = page;
        });
      }
    }
  }

  void _goToChat() {
    _pageController.animateToPage(
      _chatPageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToCall() {
    _pageController.animateToPage(
      _callPageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToArtifact() {
    _pageController.animateToPage(
      _artifactPageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleBackButton() {
    if (_currentPageIndex == _chatPageIndex || _currentPageIndex == _artifactPageIndex) {
      _goToCall();
    } else {
      final isCallActive = ref.read(isCallActiveProvider);
      if (isCallActive) {
        _showSnackBar('通話を終了してからアプリを閉じてください', isError: true);
      }
    }
  }

  bool get _canPop {
    if (_currentPageIndex == _chatPageIndex || _currentPageIndex == _artifactPageIndex) {
      return false;
    }
    return !ref.read(isCallActiveProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for errors from call service
    ref.listen(callErrorProvider, (previous, next) {
      next.whenData((error) {
        _showSnackBar(error, isError: true);
      });
    });

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackButton();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: AppTheme.backgroundGradient,
          child: SafeArea(
            child: PageView(
              controller: _pageController,
              children: [
                // Chat on left (swipe right to go to call)
                ChatPage(
                  onBackPressed: _goToCall,
                ),
                // Call in center
                CallPage(
                  onChatPressed: _goToChat,
                  onNotepadPressed: _goToArtifact,
                  onSettingsPressed: _openSettings,
                ),
                // Artifacts on right (swipe left to go to call)
                NotepadPage(
                  onBackPressed: _goToCall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
