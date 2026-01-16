import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/settings/widgets/settings_card.dart';
import 'package:vagina/providers/providers.dart';
import 'package:vagina/theme/app_theme.dart';
import 'package:vagina/widgets/adaptive_widgets.dart';

/// UI preferences section for Material/Cupertino style selection
class UiPreferencesSection extends ConsumerWidget {
  const UiPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCupertinoStyle = ref.watch(useCupertinoStyleProvider);
    
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: AppTheme.lightTextSecondary),
            title: const Text(
              'Cupertinoスタイルを使用',
              style: TextStyle(color: AppTheme.lightTextPrimary),
            ),
            subtitle: Text(
              'iOS風のUIデザインに切り替えます',
              style: TextStyle(
                color: AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            trailing: AdaptiveSwitch(
              value: useCupertinoStyle,
              onChanged: (value) {
                ref.read(useCupertinoStyleProvider.notifier).set(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
