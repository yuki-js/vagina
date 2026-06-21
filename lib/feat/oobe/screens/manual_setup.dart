import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/feat/call/models/hosted_voice_agent_defaults.dart';
import 'package:vagina/feat/call/models/voice_agent_api_config.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Third OOBE screen – Hosted voice-agent setup.
///
/// Self-hosted OpenAI URL/API-key manual input has been removed.
/// OOBE now defaults to [HostedVoiceAgentApiConfig] with
/// [HostedVoiceAgentDefaults.defaultModelId].  The user simply taps
/// "Continue" and the config is saved before advancing.
class ManualSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const ManualSetupScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  ConsumerState<ManualSetupScreen> createState() => _ManualSetupScreenState();
}

class _ManualSetupScreenState extends ConsumerState<ManualSetupScreen> {
  bool _isSaving = false;

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);

    try {
      await AppContainer.config.saveVoiceAgentApiConfig(
        const HostedVoiceAgentApiConfig(
          modelId: HostedVoiceAgentDefaults.defaultModelId,
        ),
      );

      if (mounted) {
        widget.onContinue();
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsOpenAiSaveFailed(e.toString())),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      l10n.oobeManualSetupTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.oobeManualSetupSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Hosted-mode info card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_done_rounded,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.oobeManualSetupHostedBadge,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.oobeManualSetupHostedDescription,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.settingsHostedModelIdLabel}: ${HostedVoiceAgentDefaults.defaultModelId}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppTheme.primaryColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.permissionsContinue,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      l10n.oobeManualSetupHostedNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // Back button – always top-left
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
          ),
        ],
      ),
    );
  }
}
