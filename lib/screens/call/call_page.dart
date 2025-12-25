import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../services/call_service.dart';
import '../../components/audio_level_visualizer.dart';
import '../../utils/duration_formatter.dart';
import 'control_panel.dart';

/// Call page widget - displays call UI and controls
class CallPage extends ConsumerWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final VoidCallback onSettingsPressed;
  final bool hideNavigationButtons;

  const CallPage({
    super.key,
    required this.onChatPressed,
    required this.onNotepadPressed,
    required this.onSettingsPressed,
    this.hideNavigationButtons = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callStateAsync = ref.watch(callStateProvider);
    final amplitudeAsync = ref.watch(amplitudeProvider);
    final durationAsync = ref.watch(durationProvider);
    final isMuted = ref.watch(isMutedProvider);

    final isCallActive = ref.watch(isCallActiveProvider);
    final callState = callStateAsync.value;
    final amplitude = amplitudeAsync.value ?? 0.0;
    final duration = durationAsync.value ?? 0;

    return Column(
      children: [
        // Main content area (expandable)
        Expanded(
          child: _CallMainContent(
            isCallActive: isCallActive,
            isConnecting: callState == CallState.connecting,
            isConnected: callState == CallState.connected,
            callDuration: duration,
            inputLevel: amplitude,
            isMuted: isMuted,
          ),
        ),

        // Galaxy-style control panel at bottom
        ControlPanel(
          onChatPressed: onChatPressed,
          onNotepadPressed: onNotepadPressed,
          onSettingsPressed: onSettingsPressed,
          hideNavigationButtons: hideNavigationButtons,
        ),
      ],
    );
  }
}

/// Main content area showing app logo, duration, and visualizer
class _CallMainContent extends StatelessWidget {
  final bool isCallActive;
  final bool isConnecting;
  final bool isConnected;
  final int callDuration;
  final double inputLevel;
  final bool isMuted;

  const _CallMainContent({
    required this.isCallActive,
    required this.isConnecting,
    required this.isConnected,
    required this.callDuration,
    required this.inputLevel,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App logo/title
        const Icon(
          Icons.headset_mic,
          size: 80,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        const Text(
          'VAGINA',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Voice AGI Notepad Agent',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 32),

        // Duration display (when call active)
        if (isCallActive) ...[
          Text(
            DurationFormatter.formatMinutesSeconds(callDuration),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w300,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Audio level visualizer
          AudioLevelVisualizer(
            level: inputLevel,
            isMuted: isMuted,
            isConnected: isConnected,
            height: 60,
          ),
        ],

        // Connection status (when connecting)
        if (isConnecting) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ],
      ],
    );
  }
}
