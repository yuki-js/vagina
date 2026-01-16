import 'package:flutter/material.dart';
import 'package:vagina/feat/settings/screens/log.dart';
import 'package:vagina/feat/settings/widgets/settings_card.dart';
import 'package:vagina/theme/app_theme.dart';

/// 開発者向け設定セクション
class DeveloperSection extends StatelessWidget {
  const DeveloperSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.article_outlined, color: AppTheme.lightTextSecondary),
            title: const Text(
              'ログを表示',
              style: TextStyle(color: AppTheme.lightTextPrimary),
            ),
            subtitle: Text(
              'トレースログとWebSocketイベントを確認',
              style: TextStyle(
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.lightTextSecondary),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LogScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
