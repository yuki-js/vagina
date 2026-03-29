import 'package:flutter/material.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// First OOBE screen - Welcome experience with mic motif and features
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const WelcomeScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  static const int _rotatingMessageCount = 4;

  late AnimationController _pulseController;
  int _currentMessageIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Cycle through messages
    Future.delayed(const Duration(seconds: 2), _cycleMessages);
  }

  void _cycleMessages() {
    if (!mounted) return;
    setState(() {
      _currentMessageIndex =
          (_currentMessageIndex + 1) % (_rotatingMessageCount + 1);
    });
    Future.delayed(const Duration(seconds: 2), _cycleMessages);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final welcomeMessages = [
      l10n.welcomeTitle(AppConfig.appName),
      l10n.welcomeHeroMessageThoughts,
      l10n.welcomeHeroMessageRealtimeAi,
      l10n.welcomeHeroMessageCreativePartner,
      l10n.welcomeHeroMessageSubtitle,
    ];

    return GestureDetector(
      onTap: widget.onContinue,
      behavior: HitTestBehavior.opaque,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsating microphone visualizer
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        stops: [
                          0.0,
                          0.5 + (_pulseController.value * 0.3),
                          1.0,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mic,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              // Animated title text
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Text(
                    welcomeMessages[_currentMessageIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(
                        alpha: 0.5 + (_pulseController.value * 0.5),
                      ),
                      letterSpacing: 2,
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Interaction hint
              Text(
                l10n.welcomeTapToBegin,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 48),

              // Feature highlights
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildFeatureChip(
                      l10n.welcomeFeatureRealtimeConversation,
                      Icons.voice_chat,
                    ),
                    _buildFeatureChip(
                      l10n.welcomeFeatureThoughtOrganization,
                      Icons.lightbulb_outline,
                    ),
                    _buildFeatureChip(
                      l10n.welcomeFeatureVoiceNotes,
                      Icons.note_add,
                    ),
                    _buildFeatureChip(
                      l10n.welcomeFeatureAiSupport,
                      Icons.auto_awesome,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Powered by footer
              Text(
                l10n.welcomePoweredByAokiApp,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
