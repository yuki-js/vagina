import 'package:flutter/material.dart';

import 'package:vagina/feat/oobe/screens/oobe_flow.dart';
import 'package:vagina/feat/settings/widgets/settings_card.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// セットアップセクション - OOBEの再開始など
class SetupSection extends StatelessWidget {
  const SetupSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading:
                const Icon(Icons.refresh, color: AppTheme.lightTextSecondary),
            title: Text(
              l10n.settingsSetupRestartOobeTitle,
              style: const TextStyle(color: AppTheme.lightTextPrimary),
            ),
            subtitle: Text(
              l10n.settingsSetupRestartOobeSubtitle,
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
