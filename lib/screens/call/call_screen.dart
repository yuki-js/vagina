import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../components/title_bar.dart';
import 'call_page.dart';

/// Standalone call screen with dark theme (special screen for calls)
class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
