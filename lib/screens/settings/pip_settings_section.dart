import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/settings_card.dart';
import '../../theme/app_theme.dart';
import '../../services/pip_service.dart';

/// Settings section for Picture-in-Picture options (mobile platforms only)
class PiPSettingsSection extends ConsumerStatefulWidget {
  const PiPSettingsSection({super.key});

  @override
  ConsumerState<PiPSettingsSection> createState() => _PiPSettingsSectionState();
}

class _PiPSettingsSectionState extends ConsumerState<PiPSettingsSection> {
  final PiPService _pipService = PiPService();
  bool _isPiPAvailable = false;
  bool _isPiPEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPiPAvailability();
  }

  @override
  void dispose() {
    _pipService.dispose();
    super.dispose();
  }

  Future<void> _checkPiPAvailability() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final available = await _pipService.isPiPAvailable();
        if (mounted) {
          setState(() {
            _isPiPAvailable = available;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isPiPAvailable = false;
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isPiPAvailable = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePiP(bool value) async {
    try {
      bool result;
      if (value) {
        result = await _pipService.enablePiP();
      } else {
        await _pipService.disablePiP();
        result = false;
      }
      
      setState(() {
        _isPiPEnabled = result;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'PiPモードが有効になりました' : 'PiPモードが無効になりました'),
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

  Future<void> _enterPiPNow() async {
    try {
      final result = await _pipService.enterPiPMode();
      
      if (mounted && result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PiPモードに移行しました'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PiPモードへの移行に失敗しました: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SettingsCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ),
      );
    }

    if (!_isPiPAvailable) {
      return SettingsCard(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'このデバイスではPicture-in-Picture機能はサポートされていません',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text(
              'Picture-in-Pictureを有効化',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            subtitle: const Text(
              'アプリがバックグラウンドに移動した際にPiPモードに移行します',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            value: _isPiPEnabled,
            onChanged: _togglePiP,
            activeThumbColor: AppTheme.primaryColor,
            contentPadding: EdgeInsets.zero,
          ),
          
          if (_isPiPEnabled && Platform.isAndroid) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.textSecondary, height: 1),
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enterPiPNow,
                icon: const Icon(Icons.picture_in_picture_alt, size: 18),
                label: const Text('今すぐPiPモードに移行'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '※ 通話中にPiPモードを使用すると、他のアプリを使いながら会話を継続できます',
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
