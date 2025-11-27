import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../settings_card.dart';
import '../../screens/log_screen.dart';
import '../../screens/flutter_sound_bug_repro_screen.dart';

/// Developer settings section widget
class DeveloperSettingsSection extends StatelessWidget {
  const DeveloperSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.article_outlined, color: AppTheme.textSecondary),
            title: const Text(
              'ログを表示',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'トレースログとWebSocketイベントを確認',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LogScreen()),
              );
            },
          ),
          const Divider(color: AppTheme.surfaceColor),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined, color: AppTheme.warningColor),
            title: const Text(
              'flutter_sound バグ再現',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Race condition bug reproduction screen',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const FlutterSoundBugReproScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
