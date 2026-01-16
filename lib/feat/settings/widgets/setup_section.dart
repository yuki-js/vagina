import 'package:flutter/material.dart';

import 'package:vagina/feat/oobe/screens/oobe_flow.dart';
import 'package:vagina/feat/settings/widgets/settings_card.dart';
import 'package:vagina/theme/app_theme.dart';

/// セットアップセクション - OOBEの再開始など
class SetupSection extends StatelessWidget {
  const SetupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh, color: AppTheme.lightTextSecondary),
            title: const Text(
              '初期設定をやり直す',
              style: TextStyle(color: AppTheme.lightTextPrimary),
            ),
            subtitle: Text(
              'ウェルカム画面から初期設定を再実行',
              style: TextStyle(
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            trailing:
                const Icon(Icons.chevron_right, color: AppTheme.lightTextSecondary),
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const OobeFlowScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
