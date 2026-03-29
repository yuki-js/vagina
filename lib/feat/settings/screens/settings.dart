import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/core/state/repository_providers.dart';
import 'package:vagina/feat/settings/widgets/azure_config_section.dart';
import 'package:vagina/feat/settings/widgets/setup_section.dart';
import 'package:vagina/feat/settings/widgets/settings_card.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// 設定画面 - API設定など
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsScreenTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SectionHeader(title: l10n.settingsLanguageSectionTitle),
                const SizedBox(height: 12),
                const _LanguageSelectorCard(),
                const SizedBox(height: 24),

                // Azure OpenAI Configuration Section
                SectionHeader(title: l10n.settingsAzureConfigSectionTitle),
                const SizedBox(height: 12),
                const AzureConfigSection(),
                const SizedBox(height: 24),

                // Setup Section
                SectionHeader(title: l10n.settingsSetupSectionTitle),
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

class _LanguageSelectorCard extends ConsumerWidget {
  const _LanguageSelectorCard();

  static const String _systemSelection = 'system';
  static const String _japaneseSelection = 'ja';
  static const String _englishSelection = 'en';

  String _selectionFromLocaleCode(String? localeCode) {
    switch (localeCode) {
      case 'ja':
        return _japaneseSelection;
      case 'en':
        return _englishSelection;
      default:
        return _systemSelection;
    }
  }

  String? _localeCodeFromSelection(String selection) {
    switch (selection) {
      case _japaneseSelection:
        return 'ja';
      case _englishSelection:
        return 'en';
      default:
        return null;
    }
  }

  Future<void> _persistLocaleSelection(WidgetRef ref, String selection) async {
    final localeCode = _localeCodeFromSelection(selection);
    await ref
        .read(preferencesRepositoryProvider)
        .setPreferredLocaleCode(localeCode);
    ref.read(appLocaleCodeProvider.notifier).state = localeCode;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedValue =
        _selectionFromLocaleCode(ref.watch(appLocaleCodeProvider));

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsLanguageLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedValue,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: _systemSelection,
                child: Text(l10n.settingsLanguageOptionSystemDefault),
              ),
              DropdownMenuItem(
                value: _japaneseSelection,
                child: Text(l10n.settingsLanguageOptionJapanese),
              ),
              DropdownMenuItem(
                value: _englishSelection,
                child: Text(l10n.settingsLanguageOptionEnglish),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              _persistLocaleSelection(ref, value);
            },
          ),
        ],
      ),
    );
  }
}
