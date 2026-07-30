import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vagina/core/config/constants.dart';
import 'package:vagina/core/state/locale_providers.dart';
import 'package:vagina/core/app/app_container.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/core/widgets/keycap.dart';
import 'package:vagina/feat/oobe/screens/oobe_flow.dart';
import 'package:vagina/feat/settings/widgets/settings_card.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/global_hotkey_binding.dart';
import 'package:vagina/models/push_to_talk_key_binding.dart';
import 'package:vagina/services/platform/global_hotkey_service.dart';

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

                // System-wide shortcuts, where the platform supports them.
                if (GlobalHotkeyService.isSupportedPlatform) ...[
                  SectionHeader(title: l10n.settingsGlobalHotkeySectionTitle),
                  const SizedBox(height: 12),
                  const _GlobalHotkeyCard(),
                  const SizedBox(height: 24),
                ],

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
  static final Uri _termsOfServiceUrl = Uri.parse(Constants.termsOfServiceUrl);
  static final Uri _privacyPolicyUrl = Uri.parse(Constants.privacyPolicyUrl);

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
  static const int _defaultSilenceTimeoutSeconds = 180;
  static const List<int> _silenceTimeoutSecondsOptions = [
    30,
    60,
    180,
    300,
    600,
    1800,
  ];

  int _selectedTimeoutSeconds = _defaultSilenceTimeoutSeconds;
  PushToTalkKeyBinding? _pushToTalkKeyBinding;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final preferences = AppContainer.preferences;
    final timeoutSeconds = await preferences
        .getPreferredCallIdleDisconnectTimeoutSeconds();
    final pushToTalkKeyBinding = await preferences
        .getPreferredCallPushToTalkKeyBinding();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTimeoutSeconds = timeoutSeconds;
      _pushToTalkKeyBinding = pushToTalkKeyBinding;
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

  Future<void> _openPushToTalkKeyRecorder() async {
    final result = await showDialog<_PushToTalkKeyRecorderResult>(
      context: context,
      builder: (context) =>
          _PushToTalkKeyRecorderDialog(initialBinding: _pushToTalkKeyBinding),
    );
    if (!mounted || result == null) {
      return;
    }

    final binding = result.binding;
    if (binding == _pushToTalkKeyBinding) {
      return;
    }

    setState(() {
      _pushToTalkKeyBinding = binding;
    });
    await AppContainer.preferences.setPreferredCallPushToTalkKeyBinding(
      binding,
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
              for (final timeoutSeconds in _silenceTimeoutSecondsOptions)
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
          const SizedBox(height: 20),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !_isLoading,
              title: Text(
                l10n.settingsCallPushToTalkKeyLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.settingsCallPushToTalkKeyHelper),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PushToTalkKeyBindingPreview(
                    binding: _pushToTalkKeyBinding,
                    unsetLabel: l10n.settingsCallPushToTalkKeyUnset,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: _openPushToTalkKeyRecorder,
            ),
          ),
        ],
      ),
    );
  }
}

/// Assigns the system-wide shortcuts that drive a call from another window.
class _GlobalHotkeyCard extends StatefulWidget {
  const _GlobalHotkeyCard();

  @override
  State<_GlobalHotkeyCard> createState() => _GlobalHotkeyCardState();
}

class _GlobalHotkeyCardState extends State<_GlobalHotkeyCard> {
  Map<GlobalHotkeyAction, GlobalHotkeyBinding> _bindings =
      const <GlobalHotkeyAction, GlobalHotkeyBinding>{};
  Set<GlobalHotkeyAction> _rejectedActions = const <GlobalHotkeyAction>{};
  bool _isLoading = true;
  int _validationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadBindings();
  }

  Future<void> _loadBindings() async {
    final bindings = await AppContainer.preferences
        .getPreferredGlobalHotkeyBindings();
    if (!mounted) {
      return;
    }

    setState(() {
      _bindings = bindings;
      _isLoading = false;
    });
    await _refreshRejectedActions(bindings);
  }

  /// Registers the bindings briefly to learn which ones the OS refuses.
  ///
  /// A refusal means another application already owns the combination, which is
  /// only visible by asking the OS, so settings asks here rather than leaving
  /// the user with a shortcut that silently does nothing during a call.
  Future<void> _refreshRejectedActions(
    Map<GlobalHotkeyAction, GlobalHotkeyBinding> bindings,
  ) async {
    // A newer check supersedes an older one, whose answer is about a set of
    // bindings the user has already moved on from.
    final generation = ++_validationGeneration;

    if (bindings.isEmpty) {
      if (mounted && _rejectedActions.isNotEmpty) {
        setState(() {
          _rejectedActions = const <GlobalHotkeyAction>{};
        });
      }
      return;
    }

    final service = GlobalHotkeyService();
    try {
      final rejectedActions = await service.apply(bindings);
      if (!mounted || generation != _validationGeneration) {
        return;
      }
      setState(() {
        _rejectedActions = rejectedActions;
      });
    } finally {
      await service.dispose();
    }
  }

  Future<void> _openRecorder(GlobalHotkeyAction action) async {
    final result = await showDialog<_GlobalHotkeyRecorderResult>(
      context: context,
      builder: (context) =>
          _GlobalHotkeyRecorderDialog(initialBinding: _bindings[action]),
    );
    if (!mounted || result == null) {
      return;
    }

    final binding = result.binding;
    if (binding == _bindings[action]) {
      return;
    }

    await AppContainer.preferences.setPreferredGlobalHotkeyBinding(
      action,
      binding,
    );
    final bindings = Map<GlobalHotkeyAction, GlobalHotkeyBinding>.of(_bindings);
    if (binding == null) {
      bindings.remove(action);
    } else {
      bindings[action] = binding;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _bindings = bindings;
    });
    await _refreshRejectedActions(bindings);
  }

  String _actionLabel(AppLocalizations l10n, GlobalHotkeyAction action) {
    return switch (action) {
      GlobalHotkeyAction.pushToTalk =>
        l10n.settingsGlobalHotkeyActionPushToTalk,
      GlobalHotkeyAction.pushToTalkToggle =>
        l10n.settingsGlobalHotkeyActionPushToTalkToggle,
      GlobalHotkeyAction.cancelInput =>
        l10n.settingsGlobalHotkeyActionCancelInput,
      GlobalHotkeyAction.interrupt => l10n.settingsGlobalHotkeyActionInterrupt,
      GlobalHotkeyAction.muteToggle =>
        l10n.settingsGlobalHotkeyActionMuteToggle,
    };
  }

  String _actionHelper(AppLocalizations l10n, GlobalHotkeyAction action) {
    return switch (action) {
      GlobalHotkeyAction.pushToTalk =>
        l10n.settingsGlobalHotkeyActionPushToTalkHelper,
      GlobalHotkeyAction.pushToTalkToggle =>
        l10n.settingsGlobalHotkeyActionPushToTalkToggleHelper,
      GlobalHotkeyAction.cancelInput =>
        l10n.settingsGlobalHotkeyActionCancelInputHelper,
      GlobalHotkeyAction.interrupt =>
        l10n.settingsGlobalHotkeyActionInterruptHelper,
      GlobalHotkeyAction.muteToggle =>
        l10n.settingsGlobalHotkeyActionMuteToggleHelper,
    };
  }

  String? _actionWarning(AppLocalizations l10n, GlobalHotkeyAction action) {
    if (_rejectedActions.contains(action)) {
      return l10n.settingsGlobalHotkeyConflictWarning;
    }
    if (_bindings[action]?.isBareKey ?? false) {
      return l10n.settingsGlobalHotkeyBareKeyWarning;
    }
    return null;
  }

  Widget _buildActionTile(AppLocalizations l10n, GlobalHotkeyAction action) {
    final warning = _actionWarning(l10n, action);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !_isLoading,
      title: Text(
        _actionLabel(l10n, action),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_actionHelper(l10n, action)),
          if (warning != null) ...[
            const SizedBox(height: 4),
            Text(
              warning,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.warningColor),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlobalHotkeyBindingPreview(
            binding: _bindings[action],
            unsetLabel: l10n.settingsCallPushToTalkKeyUnset,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _openRecorder(action),
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
            Text(
              l10n.settingsGlobalHotkeyHelper,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final action in GlobalHotkeyAction.values)
              _buildActionTile(l10n, action),
          ],
        ),
      ),
    );
  }
}

class _GlobalHotkeyBindingPreview extends StatelessWidget {
  final GlobalHotkeyBinding? binding;
  final String unsetLabel;

  const _GlobalHotkeyBindingPreview({
    required this.binding,
    required this.unsetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final binding = this.binding;
    if (binding == null) {
      return Keycap(token: unsetLabel, isMuted: true);
    }

    return KeycapSequence(tokens: binding.displayTokens);
  }
}

class _GlobalHotkeyRecorderResult {
  final GlobalHotkeyBinding? binding;

  const _GlobalHotkeyRecorderResult(this.binding);
}

class _GlobalHotkeyRecorderDialog extends StatefulWidget {
  final GlobalHotkeyBinding? initialBinding;

  const _GlobalHotkeyRecorderDialog({required this.initialBinding});

  @override
  State<_GlobalHotkeyRecorderDialog> createState() =>
      _GlobalHotkeyRecorderDialogState();
}

class _GlobalHotkeyRecorderDialogState
    extends State<_GlobalHotkeyRecorderDialog> {
  late final FocusNode _focusNode;
  GlobalHotkeyBinding? _candidateBinding;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _candidateBinding = widget.initialBinding;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed.toSet()
      ..add(event.logicalKey);
    // A bare modifier press cannot be a system-wide shortcut, so recording
    // continues until a usable primary key arrives.
    final binding = GlobalHotkeyBinding.fromKeyDown(
      logicalKey: event.logicalKey,
      pressedKeys: pressedKeys,
    );
    if (binding != null) {
      setState(() {
        _candidateBinding = binding;
      });
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidateBinding = _candidateBinding;

    return AlertDialog(
      title: Text(l10n.settingsGlobalHotkeyDialogTitle),
      content: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsGlobalHotkeyDialogPrompt),
              const SizedBox(height: 16),
              Center(
                child: candidateBinding == null
                    ? Keycap(
                        token: l10n.settingsCallPushToTalkKeyUnset,
                        isMuted: true,
                      )
                    : KeycapSequence(tokens: candidateBinding.displayTokens),
              ),
              if (candidateBinding?.isBareKey ?? false) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.settingsGlobalHotkeyBareKeyWarning,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.warningColor),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCommonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const _GlobalHotkeyRecorderResult(null)),
          child: Text(l10n.settingsCommonClear),
        ),
        FilledButton(
          onPressed: candidateBinding == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop(_GlobalHotkeyRecorderResult(candidateBinding)),
          child: Text(l10n.settingsCommonSave),
        ),
      ],
    );
  }
}

class _PushToTalkKeyBindingPreview extends StatelessWidget {
  final PushToTalkKeyBinding? binding;
  final String unsetLabel;

  const _PushToTalkKeyBindingPreview({
    required this.binding,
    required this.unsetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final binding = this.binding;
    if (binding == null) {
      return Keycap(token: unsetLabel, isMuted: true);
    }

    return KeycapSequence(tokens: binding.displayTokens);
  }
}

class _PushToTalkKeyRecorderResult {
  final PushToTalkKeyBinding? binding;

  const _PushToTalkKeyRecorderResult(this.binding);
}

class _PushToTalkKeyRecorderDialog extends StatefulWidget {
  final PushToTalkKeyBinding? initialBinding;

  const _PushToTalkKeyRecorderDialog({required this.initialBinding});

  @override
  State<_PushToTalkKeyRecorderDialog> createState() =>
      _PushToTalkKeyRecorderDialogState();
}

class _PushToTalkKeyRecorderDialogState
    extends State<_PushToTalkKeyRecorderDialog> {
  late final FocusNode _focusNode;
  PushToTalkKeyBinding? _candidateBinding;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _candidateBinding = widget.initialBinding;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed.toSet()
      ..add(event.logicalKey);
    final binding = PushToTalkKeyBinding.fromPressedKeys(pressedKeys);
    if (binding != null) {
      setState(() {
        _candidateBinding = binding;
      });
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidateBinding = _candidateBinding;

    return AlertDialog(
      title: Text(l10n.settingsCallPushToTalkKeyDialogTitle),
      content: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsCallPushToTalkKeyDialogPrompt),
              const SizedBox(height: 16),
              Center(
                child: candidateBinding == null
                    ? Keycap(
                        token: l10n.settingsCallPushToTalkKeyUnset,
                        isMuted: true,
                      )
                    : KeycapSequence(tokens: candidateBinding.displayTokens),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settingsCommonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const _PushToTalkKeyRecorderResult(null)),
          child: Text(l10n.settingsCommonClear),
        ),
        FilledButton(
          onPressed: candidateBinding == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop(_PushToTalkKeyRecorderResult(candidateBinding)),
          child: Text(l10n.settingsCommonSave),
        ),
      ],
    );
  }
}
