import 'package:flutter/material.dart';
import '../../components/settings_card.dart';

/// About section widget for app information
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: 'バージョン', value: '1.0.0'),
          Divider(color: Color(0xFF2C2C2E)),
          InfoRow(label: 'Powered by', value: 'Azure OpenAI Realtime API'),
        ],
      ),
    );
  }
}
