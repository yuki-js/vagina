import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/utils/duration_formatter.dart';

class CallPane extends StatefulWidget {
  final SpeedDial speedDial;
  final CallService? callService;
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final bool hideNavigationButtons;

  const CallPane({
    super.key,
    required this.speedDial,
    this.callService,
    required this.onChatPressed,
    required this.onNotepadPressed,
    this.hideNavigationButtons = false,
  });

  @override
  State<CallPane> createState() => _CallPaneState();
}

class _CallPaneState extends State<CallPane> {
  bool _speakerMuted = false;

  CallService? get _activeCallService {
    final callService = widget.callService;
    if (callService == null ||
        callService.state == CallState.uninitialized ||
        callService.state == CallState.disposed) {
      return null;
    }
    return callService;
  }

  Stream<double>? get _amplitudeStream {
    return _activeCallService?.recorderService.amplitudeStream;
  }

  Stream<bool>? get _muteStateStream {
    return _activeCallService?.recorderService.muteState;
  }

  bool get _currentIsMuted {
    return _activeCallService?.recorderService.isMuted ?? false;
  }

  bool get _isConnected {
    return _activeCallService?.state == CallState.active;
  }

  void _handleSpeakerToggle() {
    setState(() {
      _speakerMuted = !_speakerMuted;
    });
  }

  void _handleMuteToggle() {
    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    final recorderService = callService.recorderService;
    recorderService.setMute(!recorderService.isMuted);
  }

  void _handleInterrupt() {}

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _muteStateStream,
      initialData: _currentIsMuted,
      builder: (context, muteSnapshot) {
        final isMuted = muteSnapshot.data ?? false;

        return Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.speedDial.isDefault)
                    const Icon(
                      Icons.headset_mic,
                      size: 80,
                      color: AppTheme.primaryColor,
                    )
                  else if (widget.speedDial.iconEmoji != null)
                    Text(
                      widget.speedDial.iconEmoji!,
                      style: const TextStyle(fontSize: 80),
                    )
                  else
                    const Icon(
                      Icons.headset_mic,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    widget.speedDial.isDefault
                        ? AppConfig.appName
                        : widget.speedDial.name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.speedDial.isDefault)
                    Text(
                      AppConfig.appSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  const SizedBox(height: 32),
                  Text(
                    DurationFormatter.formatMinutesSeconds(0),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<double>(
                    stream: _amplitudeStream,
                    initialData: 0.0,
                    builder: (context, snapshot) {
                      return _AudioLevelVisualizer(
                        level: snapshot.data ?? 0.0,
                        isMuted: isMuted,
                        isConnected: _isConnected,
                        height: 60,
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.hideNavigationButtons)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _ControlButton(
                                  icon: Icons.chat_bubble_outline,
                                  label: 'チャット',
                                  onTap: widget.onChatPressed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ControlButton(
                                  icon: Icons.note_alt_outlined,
                                  label: 'ノートパッド',
                                  onTap: widget.onNotepadPressed,
                                ),
                              ),
                            ],
                          ),
                        if (!widget.hideNavigationButtons)
                          const SizedBox(height: 16),
                        if (widget.hideNavigationButtons) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _ControlButton(
                                  icon: _speakerMuted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  label: 'スピーカー',
                                  onTap: _handleSpeakerToggle,
                                  isActive: _speakerMuted,
                                  activeColor: AppTheme.warningColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ControlButton(
                                  icon: isMuted ? Icons.mic_off : Icons.mic,
                                  label: '消音',
                                  onTap: _handleMuteToggle,
                                  isActive: isMuted,
                                  activeColor: AppTheme.errorColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _ControlButton(
                                  icon: Icons.front_hand,
                                  label: '割込み',
                                  onTap: _handleInterrupt,
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _ControlButton(
                                  icon: _speakerMuted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  label: 'スピーカー',
                                  onTap: _handleSpeakerToggle,
                                  isActive: _speakerMuted,
                                  activeColor: AppTheme.warningColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ControlButton(
                                  icon: isMuted ? Icons.mic_off : Icons.mic,
                                  label: '消音',
                                  onTap: _handleMuteToggle,
                                  isActive: isMuted,
                                  activeColor: AppTheme.errorColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ControlButton(
                                  icon: Icons.front_hand,
                                  label: '割込み',
                                  onTap: _handleInterrupt,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 72,
                          width: 72,
                          child: FloatingActionButton(
                            heroTag: 'call_fab',
                            onPressed: () {
                              Navigator.of(context).maybePop();
                            },
                            backgroundColor: AppTheme.errorColor,
                            shape: const CircleBorder(),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AudioLevelVisualizer extends StatelessWidget {
  final double level;
  final bool isMuted;
  final bool isConnected;
  final double height;

  const _AudioLevelVisualizer({
    required this.level,
    required this.isMuted,
    required this.isConnected,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (i) {
          const barCount = 12;
          final centerOffset = (i - barCount / 2).abs() / (barCount / 2);
          final falloff = 1 - centerOffset * 0.5;
          final barLevel = (pow(level, 0.9) * falloff).clamp(0.0, 1.0);

          const minPct = 0.15;
          final pct = max(minPct, barLevel);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            width: 6,
            height: height * pct,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isMuted
                  ? AppTheme.textSecondary.withValues(alpha: 0.3)
                  : (isConnected
                      ? AppTheme.primaryColor
                          .withValues(alpha: 0.8 + barLevel * 0.2)
                      : AppTheme.textSecondary.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? AppTheme.primaryColor)
        : AppTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? (activeColor ?? AppTheme.primaryColor)
                      .withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
