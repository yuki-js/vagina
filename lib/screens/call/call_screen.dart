import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../components/title_bar.dart';
import '../../providers/providers.dart';
import 'call_page.dart';

/// Standalone call screen with dark theme (special screen for calls)
/// Auto-starts the call when the screen is opened
class CallScreen extends ConsumerStatefulWidget {
  final String? speedDialId; // Optional speed dial reference
  
  const CallScreen({super.key, this.speedDialId});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-start call when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCallIfNeeded();
    });
  }

  Future<void> _startCallIfNeeded() async {
    final callService = ref.read(callServiceProvider);
    final isActive = ref.read(isCallActiveProvider);
    
    // Only start if not already active
    if (!isActive) {
      await callService.startCall();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme, // Force dark theme for call screen
      child: Scaffold(
        body: Column(
          children: [
            // Custom title bar for desktop platforms
            const CustomTitleBar(),
            Expanded(
              child: Container(
                decoration: AppTheme.backgroundGradient,
                child: SafeArea(
                  child: CallPage(
                    speedDialId: widget.speedDialId,
                    onChatPressed: () {}, // Not used in standalone mode
                    onNotepadPressed: () {}, // Not used in standalone mode
                    onSettingsPressed: () {}, // Settings removed from call screen
                    hideNavigationButtons: true, // Hide all navigation buttons
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
