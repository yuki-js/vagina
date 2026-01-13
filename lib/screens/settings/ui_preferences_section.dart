import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../components/settings_card.dart';
import '../../components/adaptive_widgets.dart';
import '../../providers/providers.dart';

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
