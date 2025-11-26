import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina_ui/vagina_ui.dart';
import 'package:vagina_audio/vagina_audio.dart';
import 'package:vagina_core/vagina_core.dart';
import 'settings_screen.dart';

/// Error message provider for displaying errors to users
final errorMessageProvider = StateProvider<String?>((ref) => null);

/// Input level provider (0.0 - 1.0)
final inputLevelProvider = StateProvider<double>((ref) => 0.0);

/// Main call screen with mute, disconnect, and settings buttons
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with SingleTickerProviderStateMixin {
  Timer? _callTimer;
  Timer? _levelSimTimer;
  int _callDuration = 0;
  bool _isCallActive = false;

  @override
  void dispose() {
    _callTimer?.cancel();
    _levelSimTimer?.cancel();
    super.dispose();
  }

  Future<void> _startCall() async {
    // Clear any previous errors
    ref.read(errorMessageProvider.notifier).state = null;
    
    // Check if Azure settings are configured
    final storage = ref.read(secureStorageServiceProvider);
    final hasConfig = await storage.hasAzureConfig();
    
    if (!hasConfig) {
      _showError('Azure OpenAI設定を先に行ってください');
      return;
    }
    
    setState(() {
      _isCallActive = true;
      _callDuration = 0;
    });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
    
    // Simulate mic input level for demo (will be replaced with real audio data)
    _levelSimTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final isMuted = ref.read(isMutedProvider);
      if (!isMuted && _isCallActive) {
        // Simulate varying input levels
        ref.read(inputLevelProvider.notifier).state = 
            0.1 + Random().nextDouble() * 0.7;
      } else {
        ref.read(inputLevelProvider.notifier).state = 0.0;
      }
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    _levelSimTimer?.cancel();
    ref.read(inputLevelProvider.notifier).state = 0.0;
    setState(() {
      _isCallActive = false;
      _callDuration = 0;
    });
  }

  void _showError(String message) {
    ref.read(errorMessageProvider.notifier).state = message;
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
                  backgroundColor: AppTheme.surfaceColor.withOpacity(0.6),
                  onPressed: _openSettings,
                ),
              ),

              // Error banner (top)
              if (errorMessage != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ref.read(errorMessageProvider.notifier).state = null;
                          },
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo/title
                    const Icon(
                      Icons.headset_mic,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'VAGINA',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Voice AGI Native App',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Audio level visualizer (bouncing bars)
                    if (_isCallActive) ...[
                      _AudioLevelVisualizer(
                        level: inputLevel,
                        isMuted: isMuted,
                        isConnected: _isCallActive,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isMuted ? AppTheme.errorColor : AppTheme.successColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isMuted 
                                  ? 'ミュート中 • ${_formatDuration(_callDuration)}'
                                  : '録音中 • ${_formatDuration(_callDuration)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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
                            ref.read(isMutedProvider.notifier).state = !isMuted;
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
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'End-to-end encrypted',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.5),
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

/// Audio level visualizer with bouncing bars
class _AudioLevelVisualizer extends StatelessWidget {
  final double level;
  final bool isMuted;
  final bool isConnected;
  
  const _AudioLevelVisualizer({
    required this.level,
    required this.isMuted,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    const barCount = 12;
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          // Create a wave-like pattern with falloff from center
          final centerOffset = (i - barCount / 2).abs() / (barCount / 2);
          final falloff = 1 - centerOffset * 0.5;
          final barLevel = isMuted ? 0.0 : (pow(level, 0.9) * falloff).clamp(0.0, 1.0);
          
          // Minimum height percentage
          const minPct = 0.15;
          final pct = max(minPct, barLevel);
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
            width: 6,
            height: 80 * pct,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isMuted 
                  ? AppTheme.textSecondary.withOpacity(0.3)
                  : (isConnected 
                      ? AppTheme.primaryColor.withOpacity(0.8 + barLevel * 0.2)
                      : AppTheme.textSecondary.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}
