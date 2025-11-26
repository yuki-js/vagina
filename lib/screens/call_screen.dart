import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../components/components.dart';
import 'settings_screen.dart';

/// Error message provider for displaying errors to users
final errorMessageProvider = NotifierProvider<ErrorMessageNotifier, String?>(ErrorMessageNotifier.new);

/// Notifier for error message state
class ErrorMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) {
    state = message;
  }

  void clear() {
    state = null;
  }
}

/// Input level provider (0.0 - 1.0)
final inputLevelProvider = NotifierProvider<InputLevelNotifier, double>(InputLevelNotifier.new);

/// Notifier for input level state
class InputLevelNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void set(double value) {
    state = value.clamp(0.0, 1.0);
  }
}

/// Main call screen with mute, disconnect, and settings buttons
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with SingleTickerProviderStateMixin {
  Timer? _callTimer;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  int _callDuration = 0;
  bool _isCallActive = false;

  @override
  void dispose() {
    _callTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startCall() async {
    // Clear any previous errors
    ref.read(errorMessageProvider.notifier).clear();
    
    // Check if Azure settings are configured
    final storage = ref.read(secureStorageServiceProvider);
    final hasConfig = await storage.hasAzureConfig();
    
    if (!hasConfig) {
      _showError('Azure OpenAI設定を先に行ってください');
      return;
    }
    
    // Start audio recording
    final recorder = ref.read(audioRecorderServiceProvider);
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      _showError('マイクの使用を許可してください');
      return;
    }

    try {
      // Start the actual microphone recording
      final audioStream = await recorder.startRecording();
      
      setState(() {
        _isCallActive = true;
        _callDuration = 0;
      });
      
      _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _callDuration++;
        });
      });
      
      // Listen to audio stream (for potential future use with WebSocket)
      _audioStreamSubscription = audioStream.listen(
        (data) {
          // Audio data available - can be sent to WebSocket for Realtime API
        },
        onError: (error) {
          _showError('録音エラー: $error');
          _endCall();
        },
      );
      
      // Listen to amplitude for visualization
      final amplitudeStream = recorder.amplitudeStream;
      if (amplitudeStream != null) {
        _amplitudeSubscription = amplitudeStream.listen((amplitude) {
          final isMuted = ref.read(isMutedProvider);
          if (!isMuted && _isCallActive) {
            // Convert dBFS to 0-1 range. dBFS is typically -160 to 0.
            // -60 dB is quiet, 0 dB is maximum
            final normalizedLevel = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
            ref.read(inputLevelProvider.notifier).set(normalizedLevel);
          } else {
            ref.read(inputLevelProvider.notifier).set(0.0);
          }
        });
      }
    } catch (e) {
      _showError('録音の開始に失敗しました: $e');
      return;
    }
  }

  void _endCall() {
    _callTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    
    // Stop recording
    final recorder = ref.read(audioRecorderServiceProvider);
    recorder.stopRecording();
    
    ref.read(inputLevelProvider.notifier).set(0.0);
    setState(() {
      _isCallActive = false;
      _callDuration = 0;
    });
  }

  void _showError(String message) {
    ref.read(errorMessageProvider.notifier).set(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '閉じる',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = ref.watch(isMutedProvider);
    final errorMessage = ref.watch(errorMessageProvider);
    final inputLevel = ref.watch(inputLevelProvider);

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: Stack(
            children: [
              // Settings button (top right)
              Positioned(
                top: 16,
                right: 16,
                child: CircularIconButton(
                  icon: Icons.settings,
                  size: 48,
                  backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.6),
                  onPressed: _openSettings,
                ),
              ),

              // Error banner (top)
              if (errorMessage != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 80,
                  child: ErrorBanner(
                    message: errorMessage,
                    onDismiss: () {
                      ref.read(errorMessageProvider.notifier).clear();
                    },
                  ),
                ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo/title
                    const AppHeader(),

                    const SizedBox(height: 32),

                    // Audio level visualizer (bouncing bars)
                    if (_isCallActive) ...[
                      AudioLevelVisualizer(
                        level: inputLevel,
                        isMuted: isMuted,
                        isConnected: _isCallActive,
                      ),
                      const SizedBox(height: 16),
                      StatusIndicator(
                        isMuted: isMuted,
                        duration: _formatDuration(_callDuration),
                      ),
                      const SizedBox(height: 32),
                    ],

                    const SizedBox(height: 48),

                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mute button
                        CircularIconButton(
                          icon: isMuted ? Icons.mic_off : Icons.mic,
                          size: 64,
                          isActive: isMuted,
                          activeBackgroundColor: AppTheme.errorColor,
                          onPressed: () {
                            ref.read(isMutedProvider.notifier).toggle();
                          },
                        ),

                        const SizedBox(width: 32),

                        // Call button (start/end call)
                        CallButton(
                          isCallActive: _isCallActive,
                          size: 80,
                          onPressed: () {
                            if (_isCallActive) {
                              _endCall();
                            } else {
                              _startCall();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom status bar
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      size: 16,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'End-to-end encrypted',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
