import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/core/widgets/adaptive_tri_column_layout.dart';
import 'package:vagina/feat/callv2/panes/call.dart';
import 'package:vagina/feat/callv2/panes/chat.dart';
import 'package:vagina/feat/callv2/panes/notepad.dart';
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
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF07111A),
                Color(0xFF102B33),
                Color(0xFF3E2A1F),
                Color(0xFF090B10),
              ],
              stops: [0.0, 0.36, 0.74, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                top: -120,
                left: -80,
                child: _GradientGlow(
                  size: 320,
                  color: Color(0xFF1F8A70),
                  opacity: 0.18,
                ),
              ),
              const Positioned(
                right: -110,
                bottom: -90,
                child: _GradientGlow(
                  size: 360,
                  color: Color(0xFFE0A458),
                  opacity: 0.14,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
              SafeArea(
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
                      left: const ChatPane(),
                      center: CallPane(
                        speedDial: widget.speedDial,
                        onChatPressed: _layoutController.goToLeft,
                        onNotepadPressed: _layoutController.goToRight,
                        hideNavigationButtons: isWideLayout,
                      ),
                      right: const NotepadPane(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GradientGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.45),
              Colors.transparent,
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      ),
    );
  }
}
