import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/call/panes/call.dart';
import 'package:vagina/feat/call/panes/chat.dart';
import 'package:vagina/feat/call/panes/notepad.dart';
import 'package:vagina/feat/call/state/call_service_providers.dart';
import 'package:vagina/feat/call/state/call_stream_providers.dart';
import 'package:vagina/feat/call/state/call_ui_state_providers.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/services/call_service.dart';

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
    final isActive = ref.read(callStateInfoProvider).isActive;

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
    // Listen for call state changes to detect when call ends
    // This handles navigation when end_call is triggered from tools
    ref.listen<AsyncValue<CallState>>(callStateProvider, (previous, next) {
      next.whenData((state) {
        if (state == CallState.idle && mounted) {
          // Call has ended, navigate back to home
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      });
    });

    // Listen for errors from call service via consolidated UI-state stream.
    // Dedupe so that amplitude/duration updates don't re-show the same error.
    ref.listen<AsyncValue<CallUiState>>(callUiStateProvider, (previous, next) {
      final previousError = previous?.maybeWhen(
        data: (ui) => ui.metrics.lastError,
        orElse: () => null,
      );
      final nextError = next.maybeWhen(
        data: (ui) => ui.metrics.lastError,
        orElse: () => null,
      );
      if (nextError != null &&
          nextError.isNotEmpty &&
          nextError != previousError) {
        _showSnackBar(nextError, isError: true);
      }
    });

    // CallSession scope: CallScoped providers are created/destroyed with this scope
    // UI-state toggles (isMuted, speakerMuted) are reset on every CallScreen mount
    return ProviderScope(
      child: _CallSessionContent(
        pageController: _pageController,
        currentPageIndex: _currentPageIndex,
        speedDial: widget.speedDial,
        canPop: _canPop,
        onBackButton: _handleBackButton,
        onGoToChat: _goToChat,
        onGoToCall: _goToCall,
        onGoToNotepad: _goToNotepad,
        buildPageViewLayout: _buildPageViewLayout,
        buildThreeColumnLayout: _buildThreeColumnLayout,
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
              onNotepadPressed:
                  () {}, // No navigation needed in 3-column layout
              hideNavigationButtons:
                  true, // Hide chat/notepad buttons in 3-column layout
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

/// Content widget inside CallSession ProviderScope
/// This ensures all CallScoped providers are created/destroyed together with this subtree
class _CallSessionContent extends ConsumerStatefulWidget {
 final PageController pageController;
 final int currentPageIndex;
 final SpeedDial speedDial;
 final bool canPop;
 final VoidCallback onBackButton;
 final VoidCallback onGoToChat;
 final VoidCallback onGoToCall;
 final VoidCallback onGoToNotepad;
 final Widget Function() buildPageViewLayout;
 final Widget Function() buildThreeColumnLayout;

 const _CallSessionContent({
   required this.pageController,
   required this.currentPageIndex,
   required this.speedDial,
   required this.canPop,
   required this.onBackButton,
   required this.onGoToChat,
   required this.onGoToCall,
   required this.onGoToNotepad,
   required this.buildPageViewLayout,
   required this.buildThreeColumnLayout,
 });

 @override
 ConsumerState<_CallSessionContent> createState() =>
     _CallSessionContentState();
}

class _CallSessionContentState extends ConsumerState<_CallSessionContent> {
 @override
 void initState() {
   super.initState();
   // Auto-start call when content widget mounts (inside CallSession scope)
   WidgetsBinding.instance.addPostFrameCallback((_) {
     _startCallIfNeeded();
   });
 }

 Future<void> _startCallIfNeeded() async {
   final callService = ref.read(callServiceProvider);
   final isActive = ref.read(callStateInfoProvider).isActive;

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

 @override
 Widget build(BuildContext context) {
   // Listen for call state changes to detect when call ends
   // This handles navigation when end_call is triggered from tools
   ref.listen<AsyncValue<CallState>>(callStateProvider, (previous, next) {
     next.whenData((state) {
       if (state == CallState.idle && mounted) {
         // Call has ended, navigate back to home
         Navigator.of(context).pushNamedAndRemoveUntil(
           '/',
           (route) => false,
         );
       }
     });
   });

   // Listen for errors from call service via consolidated UI-state stream.
   // Dedupe so that amplitude/duration updates don't re-show the same error.
   ref.listen<AsyncValue<CallUiState>>(callUiStateProvider, (previous, next) {
     final previousError = previous?.maybeWhen(
       data: (ui) => ui.metrics.lastError,
       orElse: () => null,
     );
     final nextError = next.maybeWhen(
       data: (ui) => ui.metrics.lastError,
       orElse: () => null,
     );
     if (nextError != null &&
         nextError.isNotEmpty &&
         nextError != previousError) {
       _showSnackBar(nextError, isError: true);
     }
   });

   return PopScope(
     canPop: widget.canPop,
     onPopInvokedWithResult: (didPop, result) {
       if (!didPop) {
         widget.onBackButton();
       }
     },
     child: Theme(
       data: AppTheme.darkTheme,
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
                         return widget.buildThreeColumnLayout();
                       } else {
                         // Use PageView for mobile/narrow screens
                         return widget.buildPageViewLayout();
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
}
