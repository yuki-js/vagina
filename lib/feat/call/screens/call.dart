import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/call/panes/call.dart';
import 'package:vagina/feat/call/panes/chat.dart';
import 'package:vagina/feat/call/panes/notepad.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/feat/call/state/call_stream_providers.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/theme/app_theme.dart';

/// Call screen with PageView for swipe navigation between chat, call, and notepad
/// Layout: Chat (left) ← Call (center) → Notepad (right)
/// Dark theme for focused calling experience
class CallScreen extends ConsumerStatefulWidget {
  final SpeedDial speedDial;

  const CallScreen({
    super.key,
    required this.speedDial,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  /// Page indices for navigation
  /// Chat on left, Call in center, Notepad on right
  static const int _chatPageIndex = 0;
  static const int _callPageIndex = 1;
  static const int _notepadPageIndex = 2;

  late final PageController _pageController;
  int _currentPageIndex = _callPageIndex;

  @override
  void initState() {
    super.initState();
    // Start on the call page (center)
    _pageController = PageController(initialPage: _callPageIndex);
    _pageController.addListener(_onPageChanged);
    
    // Auto-start call when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCallIfNeeded();
    });
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

  Future<void> _startCallIfNeeded() async {
    final callService = ref.read(callServiceProvider);
    final isActive = ref.read(isCallActiveProvider);
    
    // Only start if not already active
    if (!isActive) {
      // Set assistant config from SpeedDial before starting call
      callService.setAssistantConfig(
        widget.speedDial.voice,
        widget.speedDial.systemPrompt,
      );
      
      // Set the speed dial ID for session tracking
      callService.setSpeedDialId(widget.speedDial.id);
      
      await callService.startCall();
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

  void _goToNotepad() {
    _pageController.animateToPage(
      _notepadPageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleBackButton() {
    if (_currentPageIndex == _chatPageIndex ||
        _currentPageIndex == _notepadPageIndex) {
      _goToCall();
    } else {
      // On call page, allow navigation back to home
      Navigator.of(context).pop();
    }
  }

  bool get _canPop {
    // Can't pop if on side pages (must go to call page first)
    if (_currentPageIndex == _chatPageIndex ||
        _currentPageIndex == _notepadPageIndex) {
      return false;
    }
    // Can pop from call page
    return true;
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
      child: Theme(
        data: AppTheme.darkTheme, // Force dark theme for call screen
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: AppTheme.backgroundGradient,
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Use multi-column layout for wide screens (>= 900px)
                        if (constraints.maxWidth >= 900) {
                          return _buildThreeColumnLayout();
                        } else {
                          // Use PageView for mobile/narrow screens
                          return _buildPageViewLayout();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageViewLayout() {
    return PageView(
      controller: _pageController,
      children: [
        // Chat on left (swipe right to go to call)
        ChatPane(
          onBackPressed: _goToCall,
        ),
        // Call in center
        CallPane(
          onChatPressed: _goToChat,
          onNotepadPressed: _goToNotepad,
          speedDial: widget.speedDial,
        ),
        // Notepad on right (swipe left to go to call)
        NotepadPane(
          onBackPressed: _goToCall,
        ),
      ],
    );
  }

  Widget _buildThreeColumnLayout() {
    return Row(
      children: [
        Expanded(
          flex: 40,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: AppTheme.textSecondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: ChatPane(
              onBackPressed: () {}, // No back action needed in 3-column layout
              hideBackButton: true, // Hide back button in 3-column layout
            ),
          ),
        ),
        Expanded(
          flex: 30,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: AppTheme.textSecondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: CallPane(
              onChatPressed: () {}, // No navigation needed in 3-column layout
              onNotepadPressed: () {}, // No navigation needed in 3-column layout
              hideNavigationButtons: true, // Hide chat/notepad buttons in 3-column layout
              speedDial: widget.speedDial,
            ),
          ),
        ),
        Expanded(
          flex: 40,
          child: NotepadPane(
            onBackPressed: () {}, // No back action needed in 3-column layout
            hideBackButton: true, // Hide back button in 3-column layout
          ),
        ),
      ],
    );
  }
}
