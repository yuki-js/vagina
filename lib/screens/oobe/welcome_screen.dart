import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
  late AnimationController _pulseController;

  final List<String> _welcomeMessages = [
    'VAGINAへようこそ！',
    '声で、思考を解き放つ',
    'リアルタイムAI会話',
    'あなたの創造性パートナー',
    'Voice AGI Notepad Agent',
  ];

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
      _currentMessageIndex = (_currentMessageIndex + 1) % _welcomeMessages.length;
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
                    _welcomeMessages[_currentMessageIndex],
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
                'タップしてはじめる',
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
                    _buildFeatureChip('リアルタイム会話', Icons.voice_chat),
                    _buildFeatureChip('思考整理', Icons.lightbulb_outline),
                    _buildFeatureChip('音声メモ', Icons.note_add),
                    _buildFeatureChip('AI支援', Icons.auto_awesome),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Powered by footer
              Text(
                'Proudly powered by AokiApp',
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
