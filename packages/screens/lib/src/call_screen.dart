import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina_ui/vagina_ui.dart';
import 'package:vagina_audio/vagina_audio.dart';
import 'settings_screen.dart';

/// Error message provider for displaying errors to users
final errorMessageProvider = StateProvider<String?>((ref) => null);

/// Main call screen with mute, disconnect, and settings buttons
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _callTimer;
  int _callDuration = 0;
  bool _isCallActive = false;

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  void _startCall() {
    // Clear any previous errors
    ref.read(errorMessageProvider.notifier).state = null;
    
    setState(() {
      _isCallActive = true;
      _callDuration = 0;
    });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  void _endCall() {
    _callTimer?.cancel();
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
          label: 'Dismiss',
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

                    const SizedBox(height: 48),

                    // Call status
                    if (_isCallActive) ...[
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
                              decoration: const BoxDecoration(
                                color: AppTheme.successColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Connected • ${_formatDuration(_callDuration)}',
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
