import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/feat/call/services/call_service.dart';
import 'package:vagina/feat/call/services/realtime/realtime_provider_extensions.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/utils/duration_formatter.dart';

enum _TalkMode { ptt, hf }

enum _NoiseReductionMode { off, nearField, farField }

class CallPane extends StatefulWidget {
  final SpeedDial speedDial;
  final CallService callService;
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final bool hideNavigationButtons;

  const CallPane({
    super.key,
    required this.speedDial,
    required this.callService,
    required this.onChatPressed,
    required this.onNotepadPressed,
    this.hideNavigationButtons = false,
  });

  @override
  State<CallPane> createState() => _CallPaneState();
}

class _CallPaneState extends State<CallPane> {
  _TalkMode _talkMode = _TalkMode.hf;
  _NoiseReductionMode _noiseReductionMode = _NoiseReductionMode.nearField;

  CallService? get _activeCallService {
    final callService = widget.callService;
    if (callService.state == CallState.uninitialized ||
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

  Stream<bool>? get _speakerMuteStateStream {
    return _activeCallService?.playbackService.muteState;
  }

  bool get _currentIsMuted {
    return _activeCallService?.recorderService.isMuted ?? false;
  }

  bool get _currentIsSpeakerMuted {
    return _activeCallService?.playbackService.isMuted ?? false;
  }

  bool get _isConnected {
    return _activeCallService?.state == CallState.active;
  }

  bool get _isPttMode {
    return _talkMode == _TalkMode.ptt;
  }

  bool get _showsNoiseReductionSettings {
    final voiceAgent = widget.callService.configuredVoiceAgent;
    final apiConfig = voiceAgent?.apiConfig;
    return apiConfig is SelfhostedVoiceAgentApiConfig &&
        (apiConfig.providerType == VoiceAgentProviderType.openai ||
            apiConfig.providerType == VoiceAgentProviderType.azureOpenAi);
  }

  List<Widget> _buildPrimaryControls({
    required bool isSpeakerMuted,
    required bool isMuted,
  }) {
    if (_isPttMode) {
      return [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpeakerControl(isSpeakerMuted),
            const SizedBox(width: 12),
            _buildInterruptControl(),
          ],
        ),
      ];
    }

    if (widget.hideNavigationButtons) {
      return [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpeakerControl(isSpeakerMuted),
            const SizedBox(width: 12),
            _buildMuteControl(isMuted),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildInterruptControl(),
          ],
        ),
      ];
    }

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSpeakerControl(isSpeakerMuted),
          const SizedBox(width: 12),
          _buildMuteControl(isMuted),
          const SizedBox(width: 12),
          _buildInterruptControl(),
        ],
      ),
    ];
  }

  Widget _buildSpeakerControl(bool isSpeakerMuted) {
    return Expanded(
      child: _ControlButton(
        icon: isSpeakerMuted ? Icons.volume_off : Icons.volume_up,
        label: 'スピーカー',
        onTap: _handleSpeakerToggle,
        isActive: isSpeakerMuted,
        activeColor: AppTheme.warningColor,
      ),
    );
  }

  Widget _buildMuteControl(bool isMuted) {
    return Expanded(
      child: _ControlButton(
        icon: isMuted ? Icons.mic_off : Icons.mic,
        label: '消音',
        onTap: _handleMuteToggle,
        isActive: isMuted,
        activeColor: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildInterruptControl() {
    return Expanded(
      child: _ControlButton(
        icon: Icons.front_hand,
        label: '割込み',
        onTap: _handleInterrupt,
      ),
    );
  }

  void _handleTalkModeChanged(_TalkMode value) {
    if (_talkMode == value) {
      return;
    }

    setState(() {
      _talkMode = value;
    });

    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    if (value == _TalkMode.ptt && callService.recorderService.isMuted) {
      callService.recorderService.setMute(false);
    }

    unawaited(callService.setPushToTalkEnabled(value == _TalkMode.ptt));
  }

  void _handleNoiseReductionModeChanged(_NoiseReductionMode value) {
    if (_noiseReductionMode == value) {
      return;
    }

    setState(() {
      _noiseReductionMode = value;
    });

    if (!_showsNoiseReductionSettings) {
      return;
    }

    unawaited(
      widget.callService.applyRealtimeProviderExtension(
        RealtimeProviderExtensions.inputNoiseReductionSelection,
        <String, dynamic>{
          RealtimeProviderExtensions.selectionKey: value.name,
        },
      ),
    );
  }

  void _handlePttPressStart() {
    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    unawaited(callService.beginPushToTalk());
  }

  void _handlePttPressEnd() {
    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    unawaited(callService.endPushToTalk());
  }

  void _handlePttPressCancel() {
    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    unawaited(callService.cancelPushToTalk());
  }

  Future<void> _handleSpeakerToggle() async {
    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    final playbackService = callService.playbackService;
    await playbackService.setMute(!playbackService.isMuted);
  }

  void _handleMuteToggle() {
    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    final recorderService = callService.recorderService;
    recorderService.setMute(!recorderService.isMuted);
  }

  Future<void> _handleInterrupt() async {
    final callService = _activeCallService;
    if (callService == null) {
      return;
    }

    await callService.interruptAssistantOutput();
  }

  Future<void> _handleEndCall() async {
    await widget.callService.endCall();
  }

  void _showSettingsSheet() {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: '設定',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _CallSettingsSheet(
            initialTalkMode: _talkMode,
            initialNoiseReductionMode: _noiseReductionMode,
            showNoiseReductionSettings: _showsNoiseReductionSettings,
            onTalkModeChanged: _handleTalkModeChanged,
            onNoiseReductionModeChanged: _handleNoiseReductionModeChanged,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final beginOffset = widget.hideNavigationButtons
            ? const Offset(0.12, -0.5)
            : const Offset(0.5, -0.5);

        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: ScaleTransition(
            alignment: Alignment.center,
            scale: Tween<double>(
              begin: 0,
              end: 1,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _muteStateStream,
      initialData: _currentIsMuted,
      builder: (context, muteSnapshot) {
        final isMuted = muteSnapshot.data ?? false;

        return StreamBuilder<bool>(
          stream: _speakerMuteStateStream,
          initialData: _currentIsSpeakerMuted,
          builder: (context, speakerSnapshot) {
            final isSpeakerMuted = speakerSnapshot.data ?? false;

            return StreamBuilder<Duration>(
              stream: widget.callService.timerService?.durationUpdates,
              initialData:
                  widget.callService.timerService?.elapsed ?? Duration.zero,
              builder: (context, durationSnapshot) {
                final callDuration = durationSnapshot.data ?? Duration.zero;

                return Column(
                  children: [
                    _CallHeader(
                      onChatPressed: widget.onChatPressed,
                      onNotepadPressed: widget.onNotepadPressed,
                      onSettingsPressed: _showSettingsSheet,
                    ),
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
                            DurationFormatter.formatMinutesSeconds(
                              callDuration.inSeconds,
                            ),
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
                              color:
                                  AppTheme.surfaceColor.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!widget.hideNavigationButtons)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
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
                                ..._buildPrimaryControls(
                                  isSpeakerMuted: isSpeakerMuted,
                                  isMuted: isMuted,
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 72,
                                      width: 72,
                                      child: FloatingActionButton(
                                        heroTag: 'call_fab',
                                        onPressed: _handleEndCall,
                                        backgroundColor: AppTheme.errorColor,
                                        shape: const CircleBorder(),
                                        child: const Icon(
                                          Icons.call_end,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                    if (_isPttMode) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _PttHoldButton(
                                          onPressStart: _handlePttPressStart,
                                          onPressEnd: _handlePttPressEnd,
                                          onPressCancel: _handlePttPressCancel,
                                        ),
                                      ),
                                    ]
                                  ],
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
          },
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

class _CallHeader extends StatelessWidget {
  final VoidCallback onChatPressed;
  final VoidCallback onNotepadPressed;
  final VoidCallback onSettingsPressed;

  const _CallHeader({
    required this.onChatPressed,
    required this.onNotepadPressed,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _CallHeaderIcon(
            icon: Icons.settings,
            tooltip: '設定',
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}

class _CallHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CallHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(
        icon,
        color: AppTheme.textSecondary,
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

class _PttHoldButton extends StatefulWidget {
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onPressCancel;

  const _PttHoldButton({
    required this.onPressStart,
    required this.onPressEnd,
    required this.onPressCancel,
  });

  @override
  State<_PttHoldButton> createState() => _PttHoldButtonState();
}

class _PttHoldButtonState extends State<_PttHoldButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isPressed
        ? AppTheme.primaryColor.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.04);
    final borderColor = _isPressed
        ? AppTheme.primaryColor
        : AppTheme.textSecondary.withValues(alpha: 0.16);
    final contentColor =
        _isPressed ? AppTheme.textPrimary : AppTheme.primaryColor;

    return SizedBox(
      height: 72,
      width: double.infinity,
      child: GestureDetector(
        onTapDown: (_) {
          _setPressed(true);
          widget.onPressStart();
        },
        onTapUp: (_) {
          _setPressed(false);
          widget.onPressEnd();
        },
        onTapCancel: () {
          _setPressed(false);
          widget.onPressCancel();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.18),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isPressed ? Icons.mic : Icons.mic_none,
                color: contentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _isPressed ? '離して終了' : '押して話す',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: contentColor,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallSettingsSheet extends StatefulWidget {
  final _TalkMode initialTalkMode;
  final _NoiseReductionMode initialNoiseReductionMode;
  final bool showNoiseReductionSettings;
  final ValueChanged<_TalkMode> onTalkModeChanged;
  final ValueChanged<_NoiseReductionMode> onNoiseReductionModeChanged;

  const _CallSettingsSheet({
    required this.initialTalkMode,
    required this.initialNoiseReductionMode,
    required this.showNoiseReductionSettings,
    required this.onTalkModeChanged,
    required this.onNoiseReductionModeChanged,
  });

  @override
  State<_CallSettingsSheet> createState() => _CallSettingsSheetState();
}

class _CallSettingsSheetState extends State<_CallSettingsSheet> {
  late _TalkMode _talkMode;
  late _NoiseReductionMode _noiseReductionMode;

  @override
  void initState() {
    super.initState();
    _talkMode = widget.initialTalkMode;
    _noiseReductionMode = widget.initialNoiseReductionMode;
  }

  void _handleTalkModeChanged(_TalkMode value) {
    setState(() {
      _talkMode = value;
    });
    widget.onTalkModeChanged(value);
  }

  void _handleNoiseReductionModeChanged(_NoiseReductionMode value) {
    setState(() {
      _noiseReductionMode = value;
    });
    widget.onNoiseReductionModeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '通話設定',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: '通話モード',
                    child: Row(
                      children: [
                        Expanded(
                          child: _SettingsOptionButton(
                            label: 'ハンズフリー',
                            isSelected: _talkMode == _TalkMode.hf,
                            onTap: () => _handleTalkModeChanged(_TalkMode.hf),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SettingsOptionButton(
                            label: '押して話す',
                            isSelected: _talkMode == _TalkMode.ptt,
                            onTap: () => _handleTalkModeChanged(_TalkMode.ptt),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showNoiseReductionSettings) ...[
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'ノイズ抑制',
                      child: Row(
                        children: [
                          Expanded(
                            child: _SettingsOptionButton(
                              label: 'オフ',
                              isSelected: _noiseReductionMode ==
                                  _NoiseReductionMode.off,
                              onTap: () => _handleNoiseReductionModeChanged(
                                _NoiseReductionMode.off,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SettingsOptionButton(
                              label: '近距離',
                              isSelected: _noiseReductionMode ==
                                  _NoiseReductionMode.nearField,
                              onTap: () => _handleNoiseReductionModeChanged(
                                _NoiseReductionMode.nearField,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SettingsOptionButton(
                              label: '遠距離',
                              isSelected: _noiseReductionMode ==
                                  _NoiseReductionMode.farField,
                              onTap: () => _handleNoiseReductionModeChanged(
                                _NoiseReductionMode.farField,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SettingsOptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsOptionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppTheme.primaryColor
        : AppTheme.textSecondary.withValues(alpha: 0.16);
    final backgroundColor = isSelected
        ? AppTheme.primaryColor.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.03);
    final textColor =
        isSelected ? AppTheme.textPrimary : AppTheme.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
