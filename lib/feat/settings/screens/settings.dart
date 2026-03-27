import 'package:flutter/material.dart';
import 'package:vagina/feat/settings/widgets/azure_config_section.dart';
import 'package:vagina/feat/settings/widgets/setup_section.dart';
import 'package:vagina/feat/settings/widgets/settings_card.dart';

/// 設定画面 - API設定など
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
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
    );
  }
}
