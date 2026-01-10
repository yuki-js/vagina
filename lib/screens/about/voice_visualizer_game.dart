import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../theme/app_theme.dart';
import '../../services/audio_recorder_service.dart';

/// Interactive real-time voice visualizer easter egg
/// Actually uses the microphone to visualize voice input
/// Synergizes perfectly with the app's voice features
class VoiceVisualizerGame extends StatefulWidget {
  const VoiceVisualizerGame({super.key});

  @override
  State<VoiceVisualizerGame> createState() => _VoiceVisualizerGameState();
}

class _VoiceVisualizerGameState extends State<VoiceVisualizerGame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  final AudioRecorderService _audioService = AudioRecorderService();
  
  bool _isRecording = false;
  bool _hasPermission = false;
  final List<double> _audioLevels = List.filled(50, 0.0);
  double _currentAmplitude = 0.0;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _audioService.hasPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _amplitudeSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    if (_isRecording) {
      _audioService.stopRecording();
    }
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      await _audioService.stopRecording();
      await _amplitudeSubscription?.cancel();
      await _audioStreamSubscription?.cancel();
      
      setState(() {
        _isRecording = false;
        _currentAmplitude = 0.0;
      });
      
      _pulseController.stop();
    } else {
      // Start recording
      if (!_hasPermission) {
        final hasPermission = await _audioService.hasPermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('マイクの権限が必要です'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
          return;
        }
        setState(() {
          _hasPermission = true;
        });
      }

      try {
        final audioStream = await _audioService.startRecording();
        
        // Subscribe to audio stream
        _audioStreamSubscription = audioStream.listen((data) {
          // Process audio data to extract amplitude
          if (data.isNotEmpty) {
            // Calculate RMS amplitude from PCM data
            double sum = 0;
            final samples = data.buffer.asInt16List();
            for (var sample in samples) {
              sum += sample * sample;
            }
            final rms = math.sqrt(sum / samples.length);
            final normalizedAmplitude = (rms / 32768).clamp(0.0, 1.0);
            
            if (mounted) {
              setState(() {
                _currentAmplitude = normalizedAmplitude;
                // Shift levels and add new one
                _audioLevels.removeAt(0);
                _audioLevels.add(normalizedAmplitude);
              });
            }
          }
        });

        setState(() {
          _isRecording = true;
        });
        
        _pulseController.repeat(reverse: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('声を出してみてください！'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('録音開始エラー: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
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
                  painter: VoiceVisualizerBackgroundPainter(
                    animation: _rotationController.value,
                    amplitude: _currentAmplitude,
                    isActive: _isRecording,
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
                        // Microphone button with reactive size
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + (_currentAmplitude * 0.5);
                            return Transform.scale(
                              scale: scale,
                              child: GestureDetector(
                                onTap: _toggleRecording,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: _isRecording
                                          ? [
                                              AppTheme.errorColor,
                                              AppTheme.errorColor
                                                  .withValues(alpha: 0.4),
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
                                    size: 70,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 48),

                        // Title
                        Text(
                          _isRecording ? '声を視覚化中...' : '声の可視化',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          _isRecording
                              ? 'あなたの声がリアルタイムで可視化されています'
                              : 'マイクをタップして声を可視化',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Real-time waveform visualization
                        Container(
                          height: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          child: CustomPaint(
                            painter: WaveformVisualizerPainter(
                              levels: _audioLevels,
                              isRecording: _isRecording,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Amplitude meter
                        Container(
                          width: 200,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 50),
                              width: 200 * _currentAmplitude,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.successColor,
                                    AppTheme.warningColor,
                                    AppTheme.errorColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          '音量: ${(_currentAmplitude * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
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

/// Custom painter for voice visualizer background
class VoiceVisualizerBackgroundPainter extends CustomPainter {
  final double animation;
  final double amplitude;
  final bool isActive;

  VoiceVisualizerBackgroundPainter({
    required this.animation,
    required this.amplitude,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw reactive sound waves based on amplitude
    for (int i = 0; i < 8; i++) {
      final radius = 80.0 + (animation * 400.0 + i * 50) % 400.0;
      final baseAlpha = 1.0 - ((animation + i * 0.125) % 1.0);
      final amplitudeBoost = amplitude * 0.5;
      final alpha = (baseAlpha + amplitudeBoost).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = AppTheme.primaryColor.withValues(alpha: alpha * 0.4)
        ..strokeWidth = 2 + (amplitude * 3)
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius, paint);
    }

    // Draw particles that react to voice
    final particlePaint = Paint()
      ..color = AppTheme.secondaryColor.withValues(alpha: 0.3 + amplitude * 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 30; i++) {
      final angle = (i / 30) * 2 * math.pi + (animation * 2 * math.pi);
      final distance = (size.width / 2) * (0.4 + (i % 3) * 0.15);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      final particleSize = (2.0 + (i % 3)) * (1.0 + amplitude);

      canvas.drawCircle(Offset(x, y), particleSize, particlePaint);
    }
  }

  @override
  bool shouldRepaint(VoiceVisualizerBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.isActive != isActive;
  }
}

/// Custom painter for real-time waveform
class WaveformVisualizerPainter extends CustomPainter {
  final List<double> levels;
  final bool isRecording;

  WaveformVisualizerPainter({
    required this.levels,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    final barWidth = size.width / levels.length;
    final centerY = size.height / 2;

    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      final barHeight = level * size.height * 0.9;

      // Create gradient effect based on position
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          AppTheme.primaryColor,
          AppTheme.secondaryColor,
        ],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(i * barWidth, centerY - barHeight / 2, barWidth * 0.8, barHeight),
        )
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(i * barWidth + barWidth / 2, centerY),
          width: barWidth * 0.7,
          height: math.max(barHeight, 4),
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(WaveformVisualizerPainter oldDelegate) {
    return true; // Always repaint for smooth animation
  }
}
