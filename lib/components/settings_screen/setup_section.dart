import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../components/settings_card.dart';
import '../../screens/oobe/oobe_flow.dart';

/// Setup section - OOBE restart etc
class SetupSection extends StatelessWidget {
  const SetupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading:
                const Icon(Icons.refresh, color: AppTheme.lightTextSecondary),
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
            trailing: const Icon(Icons.chevron_right,
                color: AppTheme.lightTextSecondary),
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const OOBEFlow(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
