import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/state/locale_providers.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/oobe/screens/oobe_flow.dart';
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

                // Call preferences section
                SectionHeader(title: l10n.settingsCallSectionTitle),
                const SizedBox(height: 12),
                const _CallPreferencesCard(),
                const SizedBox(height: 24),

                const _OtherSettingsCard(),
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
    await AppContainer.preferences.setPreferredLocaleCode(localeCode);
    ref.read(appLocaleCodeProvider.notifier).setLocaleCode(localeCode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedValue = _selectionFromLocaleCode(
      ref.watch(appLocaleCodeProvider),
    );

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsLanguageLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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

class _OtherSettingsCard extends StatefulWidget {
  const _OtherSettingsCard();

  @override
  State<_OtherSettingsCard> createState() => _OtherSettingsCardState();
}

class _OtherSettingsCardState extends State<_OtherSettingsCard> {
  static final Uri _termsOfServiceUrl = Uri.parse(
    'https://example.invalid/terms-of-service',
  );
  static final Uri _privacyPolicyUrl = Uri.parse(
    'https://example.invalid/privacy-policy',
  );

  bool _isLoggingOut = false;

  Future<void> _openPlaceholderUrl(Uri url) async {
    await launchUrl(url, mode: LaunchMode.platformDefault);
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    await AppContainer.auth.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const OobeFlowScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SettingsCard(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(
                Icons.description_outlined,
                color: AppTheme.lightTextSecondary,
              ),
              title: Text(
                l10n.settingsTermsOfServiceTitle,
                style: const TextStyle(color: AppTheme.lightTextPrimary),
              ),
              trailing: const Icon(
                Icons.open_in_new,
                color: AppTheme.lightTextSecondary,
              ),
              onTap: () => _openPlaceholderUrl(_termsOfServiceUrl),
            ),
            ListTile(
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: AppTheme.lightTextSecondary,
              ),
              title: Text(
                l10n.settingsPrivacyPolicyTitle,
                style: const TextStyle(color: AppTheme.lightTextPrimary),
              ),
              trailing: const Icon(
                Icons.open_in_new,
                color: AppTheme.lightTextSecondary,
              ),
              onTap: () => _openPlaceholderUrl(_privacyPolicyUrl),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: Text(
                l10n.settingsLogoutTitle,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
              trailing: _isLoggingOut
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              enabled: !_isLoggingOut,
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _CallPreferencesCard extends StatefulWidget {
  const _CallPreferencesCard();

  @override
  State<_CallPreferencesCard> createState() => _CallPreferencesCardState();
}

class _CallPreferencesCardState extends State<_CallPreferencesCard> {
  int _selectedTimeoutSeconds = AppConfig.defaultSilenceTimeoutSeconds;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final timeoutSeconds = await AppContainer.preferences
        .getPreferredCallIdleDisconnectTimeoutSeconds();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTimeoutSeconds = timeoutSeconds;
      _isLoading = false;
    });
  }

  Future<void> _handleTimeoutChanged(int timeoutSeconds) async {
    setState(() {
      _selectedTimeoutSeconds = timeoutSeconds;
    });
    await AppContainer.preferences.setPreferredCallIdleDisconnectTimeoutSeconds(
      timeoutSeconds,
    );
  }

  String _formatTimeoutLabel(AppLocalizations l10n, int timeoutSeconds) {
    return switch (timeoutSeconds) {
      30 => l10n.settingsCallIdleDisconnectTimeout30Seconds,
      60 => l10n.settingsCallIdleDisconnectTimeout1Minute,
      180 => l10n.settingsCallIdleDisconnectTimeout3Minutes,
      300 => l10n.settingsCallIdleDisconnectTimeout5Minutes,
      600 => l10n.settingsCallIdleDisconnectTimeout10Minutes,
      1800 => l10n.settingsCallIdleDisconnectTimeout30Minutes,
      _ => '${timeoutSeconds}s',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsCallIdleDisconnectTimeoutLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsCallIdleDisconnectTimeoutHelper,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedTimeoutSeconds,
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
              for (final timeoutSeconds
                  in AppConfig.silenceTimeoutSecondsOptions)
                DropdownMenuItem<int>(
                  value: timeoutSeconds,
                  child: Text(_formatTimeoutLabel(l10n, timeoutSeconds)),
                ),
            ],
            onChanged: _isLoading
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    _handleTimeoutChanged(value);
                  },
          ),
        ],
      ),
    );
  }
}
