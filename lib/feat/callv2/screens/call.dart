import 'package:flutter/material.dart';
import 'package:vagina/core/widgets/adaptive_tri_column_layout.dart';
import 'package:vagina/feat/callv2/panes/call.dart';
import 'package:vagina/feat/callv2/panes/chat.dart';
import 'package:vagina/feat/callv2/panes/notepad.dart';
import 'package:vagina/feat/callv2/widgets/call_screen_shell.dart';
import 'package:vagina/models/speed_dial.dart';

/// Temporary layout scaffold for the call rework.
class CallScreen extends StatefulWidget {
  final SpeedDial speedDial;

  const CallScreen({
    super.key,
    required this.speedDial,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const double _wideLayoutBreakpoint = 900;

  final AdaptiveTriColumnController _layoutController =
      AdaptiveTriColumnController();

  @override
  Widget build(BuildContext context) {
    return CallScreenShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout =
              constraints.maxWidth >= _wideLayoutBreakpoint;

          return AdaptiveTriColumnLayout(
            controller: _layoutController,
            wideLayoutBreakpoint: _wideLayoutBreakpoint,
            onExitRequested: () {
              Navigator.of(context).pop();
            },
            left: ChatPane(
              onBackPressed: _layoutController.goToCenter,
              hideBackButton: isWideLayout,
            ),
            center: CallPane(
              speedDial: widget.speedDial,
              onChatPressed: _layoutController.goToLeft,
              onNotepadPressed: _layoutController.goToRight,
              hideNavigationButtons: isWideLayout,
            ),
            right: NotepadPane(
              onBackPressed: _layoutController.goToCenter,
              hideBackButton: isWideLayout,
            ),
          );
        },
      ),
    );
  }
}
