import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/call/state/call_stream_providers.dart';
import 'package:vagina/feat/call/state/call_ui_state_providers.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/services/call_service.dart';
import 'package:vagina/feat/call/widgets/call_main_content.dart';
import 'package:vagina/feat/call/widgets/control_panel.dart';

/// 通話ページウィジェット - 通話UIとコントロールを表示
class CallPane extends ConsumerWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final bool hideNavigationButtons;
  final SpeedDial speedDial;

  const CallPane({
    super.key,
    required this.onChatPressed,
    required this.onNotepadPressed,
    this.hideNavigationButtons = false,
    required this.speedDial,
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
        // メインコンテンツエリア（拡張可能）
        Expanded(
          child: CallMainContent(
            isCallActive: isCallActive,
            isConnecting: callState == CallState.connecting,
            isConnected: callState == CallState.connected,
            callDuration: duration,
            inputLevel: amplitude,
            isMuted: isMuted,
            speedDial: speedDial,
          ),
        ),

        // Galaxy風コントロールパネル（下部）
        ControlPanel(
          onChatPressed: onChatPressed,
          onNotepadPressed: onNotepadPressed,
          hideNavigationButtons: hideNavigationButtons,
        ),
      ],
    );
  }
}
