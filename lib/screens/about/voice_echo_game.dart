import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Interactive voice echo chamber easter egg
/// Records voice and plays it back with visual effects
/// Synergizes with app's voice/audio features
class VoiceEchoGame extends StatefulWidget {
  const VoiceEchoGame({super.key});

  @override
  State<VoiceEchoGame> createState() => _VoiceEchoGameState();
}

class _VoiceEchoGameState extends State<VoiceEchoGame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  bool _isRecording = false;
  bool _isPlaying = false;
  final List<double> _recordedLevels = [];
  int _playbackPosition = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        // Stop recording
        _isRecording = false;
        _pulseController.stop();
      } else {
        // Start recording
        _isRecording = true;
        _isPlaying = false;
        _recordedLevels.clear();
        _pulseController.repeat(reverse: true);
        _simulateRecording();
      }
    });
  }

  void _simulateRecording() {
    // Simulate audio recording with random levels
    if (!_isRecording) return;

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_isRecording) return;
      setState(() {
        final random = math.Random();
        _recordedLevels.add(random.nextDouble());
      });
      _simulateRecording();
    });
  }

  void _playback() {
    if (_recordedLevels.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _playbackPosition = 0;
    });

    _animatePlayback();
  }

  void _animatePlayback() {
    if (!_isPlaying || _playbackPosition >= _recordedLevels.length) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = 0;
        });
      }
      return;
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_isPlaying) return;
      setState(() {
        _playbackPosition++;
      });
      _animatePlayback();
    });
  }

  void _clear() {
    setState(() {
      _recordedLevels.clear();
      _isRecording = false;
      _isPlaying = false;
      _playbackPosition = 0;
      _pulseController.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: EchoChamberPainter(
                    animation: _rotationController.value,
                    isActive: _isRecording || _isPlaying,
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
                        // Microphone button
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return GestureDetector(
                              onTap: _toggleRecording,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: _isRecording
                                        ? [
                                            AppTheme.errorColor,
                                            AppTheme.errorColor
                                                .withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ]
                                        : [
                                            AppTheme.primaryColor,
                                            AppTheme.primaryColor
                                                .withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ],
                                    stops: [
                                      0.0,
                                      0.5 + (_pulseController.value * 0.3),
                                      1.0,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        // Title
                        Text(
                          _isRecording
                              ? '録音中...'
                              : _isPlaying
                                  ? '再生中...'
                                  : '声のエコー',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          _isRecording
                              ? 'タップして停止'
                              : _recordedLevels.isEmpty
                                  ? 'マイクをタップして録音開始'
                                  : '録音済み: ${_recordedLevels.length}フレーム',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Waveform visualization
                        if (_recordedLevels.isNotEmpty)
                          Container(
                            height: 100,
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            child: CustomPaint(
                              painter: WaveformPainter(
                                levels: _recordedLevels,
                                playbackPosition: _isPlaying ? _playbackPosition : -1,
                              ),
                            ),
                          ),

                        const SizedBox(height: 48),

                        // Control buttons
                        if (_recordedLevels.isNotEmpty && !_isRecording)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isPlaying ? null : _playback,
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text('再生'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppTheme.successColor.withValues(alpha: 0.3),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _isPlaying ? null : _clear,
                                icon: const Icon(Icons.delete, size: 20),
                                label: const Text('クリア'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.errorColor.withValues(alpha: 0.3),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                      ],
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
}

/// Custom painter for echo chamber background
class EchoChamberPainter extends CustomPainter {
  final double animation;
  final bool isActive;

  EchoChamberPainter({
    required this.animation,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw echo rings
    for (int i = 0; i < 5; i++) {
      final radius = 50.0 + (animation * 300.0 + i * 60) % 300.0;
      final alpha = 1.0 - ((animation + i * 0.2) % 1.0);

      final paint = Paint()
        ..color = AppTheme.primaryColor.withValues(alpha: alpha * 0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(EchoChamberPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.isActive != isActive;
  }
}

/// Custom painter for waveform
class WaveformPainter extends CustomPainter {
  final List<double> levels;
  final int playbackPosition;

  WaveformPainter({
    required this.levels,
    required this.playbackPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final barWidth = size.width / levels.length;
    final centerY = size.height / 2;

    for (int i = 0; i < levels.length; i++) {
      final isPlayed = playbackPosition >= 0 && i <= playbackPosition;
      final barHeight = levels[i] * size.height * 0.8;

      final paint = Paint()
        ..color = isPlayed
            ? AppTheme.successColor
            : AppTheme.primaryColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(i * barWidth + barWidth / 2, centerY),
          width: barWidth * 0.8,
          height: barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.playbackPosition != playbackPosition;
  }
}
