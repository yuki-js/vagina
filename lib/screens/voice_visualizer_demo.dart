import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Hidden easter egg demo screen showcasing voice interaction capabilities
class VoiceVisualizerDemo extends StatefulWidget {
  const VoiceVisualizerDemo({super.key});

  @override
  State<VoiceVisualizerDemo> createState() => _VoiceVisualizerDemoState();
}

class _VoiceVisualizerDemoState extends State<VoiceVisualizerDemo>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  bool _isListening = false;
  int _interactionCount = 0;

  final List<String> _demoMessages = [
    'VAGINAへようこそ！',
    '声で、思考を解き放つ',
    'リアルタイムAI会話',
    'あなたの創造性パートナー',
    'Voice AGI Notepad Agent',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      _interactionCount++;
      if (_isListening) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ParticlePainter(
                    animation: _rotationController.value,
                    isListening: _isListening,
                  ),
                );
              },
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pulsating voice visualizer
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _pulseController,
                            _waveController,
                          ]),
                          builder: (context, child) {
                            return GestureDetector(
                              onTap: _toggleListening,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: _isListening
                                        ? [
                                            AppTheme.primaryColor,
                                            AppTheme.primaryColor
                                                .withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ]
                                        : [
                                            AppTheme.primaryColor
                                                .withValues(alpha: 0.5),
                                            AppTheme.primaryColor
                                                .withValues(alpha: 0.1),
                                            Colors.transparent,
                                          ],
                                    stops: [
                                      0.0,
                                      0.5 + (_pulseController.value * 0.3),
                                      1.0,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 48),

                        // Animated text display
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final messageIndex =
                                _interactionCount % _demoMessages.length;
                            return Text(
                              _demoMessages[messageIndex],
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
                          _isListening ? 'タップして停止' : 'タップして体験',
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
                      ],
                    ),
                  ),
                ),

                // Footer with stats
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'インタラクション: $_interactionCount回',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

/// Custom painter for animated particle background
class ParticlePainter extends CustomPainter {
  final double animation;
  final bool isListening;

  ParticlePainter({
    required this.animation,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppTheme.primaryColor.withValues(alpha: 0.1);

    // Draw floating particles
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * math.pi + (animation * 2 * math.pi);
      final radius = (size.width / 2) * (0.3 + (i % 3) * 0.2);
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;

      final particleSize = isListening ? 4.0 + (i % 3) * 2 : 2.0 + (i % 2);

      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        paint,
      );
    }

    // Draw wave rings when listening
    if (isListening) {
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppTheme.primaryColor.withValues(alpha: 0.2);

      for (int i = 0; i < 3; i++) {
        final waveRadius =
            100.0 + (animation * 200.0 + i * 50) % 200.0;
        final alpha = 1.0 - ((animation + i * 0.33) % 1.0);

        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          waveRadius,
          wavePaint..color = AppTheme.primaryColor.withValues(alpha: alpha * 0.3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.isListening != isListening;
  }
}
