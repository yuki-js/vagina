import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../settings_card.dart';

/// About section widget showing app info
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: 'バージョン', value: '1.0.0'),
          Divider(color: AppTheme.surfaceColor),
          InfoRow(label: 'Powered by', value: 'Azure OpenAI Realtime API'),
        ],
      ),
    );
  }
}
