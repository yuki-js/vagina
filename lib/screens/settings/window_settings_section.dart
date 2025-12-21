import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../components/settings_card.dart';
import '../../theme/app_theme.dart';

/// Settings section for window options (desktop platforms only)
class WindowSettingsSection extends ConsumerStatefulWidget {
  const WindowSettingsSection({super.key});

  @override
  ConsumerState<WindowSettingsSection> createState() => _WindowSettingsSectionState();
}

class _WindowSettingsSectionState extends ConsumerState<WindowSettingsSection> {
  bool _isAlwaysOnTop = false;

  @override
  void initState() {
    super.initState();
    _loadWindowSettings();
  }

  Future<void> _loadWindowSettings() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final isAlwaysOnTop = await windowManager.isAlwaysOnTop();
        if (mounted) {
          setState(() {
            _isAlwaysOnTop = isAlwaysOnTop;
          });
        }
      } catch (e) {
        // Window manager not available or error
      }
    }
  }

  Future<void> _toggleAlwaysOnTop(bool value) async {
    try {
      await windowManager.setAlwaysOnTop(value);
      setState(() {
        _isAlwaysOnTop = value;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '常に最前面表示が有効になりました' : '常に最前面表示が無効になりました'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('設定の変更に失敗しました: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text(
              '常に最前面で表示',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            subtitle: const Text(
              '他のウィンドウよりも常に前面に表示します',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            value: _isAlwaysOnTop,
            onChanged: _toggleAlwaysOnTop,
            activeThumbColor: AppTheme.primaryColor,
            contentPadding: EdgeInsets.zero,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '※ 通話しながら他のアプリケーションを使用する際に便利です',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
