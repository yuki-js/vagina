import '../../utils/platform_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../components/settings_card.dart';
import '../../components/settings/azure_config_section.dart';
import '../../components/settings/voice_settings_section.dart';
import '../../components/settings/android_audio_section.dart';
import '../../components/settings/developer_section.dart';
import '../../components/settings/ui_preferences_section.dart';
import '../../features/settings/components/setup_section.dart';

/// 設定画面 - API設定など
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: AppTheme.lightBackgroundGradient,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Azure OpenAI Configuration Section
                  const SectionHeader(title: 'Azure OpenAI 設定'),
                  const SizedBox(height: 12),
                  const AzureConfigSection(),
                  const SizedBox(height: 24),

                  // Voice Settings Section
                  const SectionHeader(title: '音声設定'),
                  const SizedBox(height: 12),
                  const VoiceSettingsSection(),

                  // Android Audio Settings Section (Android only)
                  if (PlatformCompat.isAndroid) ...[
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Android 音声設定'),
                    const SizedBox(height: 12),
                    const AndroidAudioSection(),
                  ],

                  // PiP Settings removed - PiP button is now in call screen control panel
                  // Window settings removed - always-on-top is now in title bar
                  const SizedBox(height: 24),

                  // UI Preferences Section
                  const SectionHeader(title: 'UI設定'),
                  const SizedBox(height: 12),
                  const UiPreferencesSection(),
                  const SizedBox(height: 24),

                  // Developer Section
                  const SectionHeader(title: '開発者向け'),
                  const SizedBox(height: 12),
                  const DeveloperSection(),
                  const SizedBox(height: 24),

                  // Setup Section
                  const SectionHeader(title: 'セットアップ'),
                  const SizedBox(height: 12),
                  const SetupSection(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
