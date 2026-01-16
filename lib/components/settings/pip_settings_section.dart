import '../../utils/platform_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pip_service.dart';
import '../settings_card.dart';

/// PiP settings section for mobile platforms
class PiPSettingsSection extends ConsumerStatefulWidget {
  const PiPSettingsSection({super.key});

  @override
  ConsumerState<PiPSettingsSection> createState() => _PiPSettingsSectionState();
}

class _PiPSettingsSectionState extends ConsumerState<PiPSettingsSection> {
  bool _isPiPAvailable = false;
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPiPAvailability();
  }

  Future<void> _checkPiPAvailability() async {
    final pipService = ref.read(pipServiceProvider);
    final available = await pipService.isPiPAvailable();

    if (mounted) {
      setState(() {
        _isPiPAvailable = available;
        _isEnabled = pipService.isEnabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePiP(bool value) async {
    final pipService = ref.read(pipServiceProvider);

    setState(() => _isLoading = true);

    if (value) {
      await pipService.enablePiP();
    } else {
      await pipService.disablePiP();
    }

    if (mounted) {
      setState(() {
        _isEnabled = value;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android and iOS
    if (!PlatformCompat.isAndroid && !PlatformCompat.isIOS) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const SettingsCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!_isPiPAvailable) {
      return SettingsCard(
        child: ListTile(
          title: const Text('PiP 利用不可'),
          subtitle: Text(
            PlatformCompat.isAndroid
                ? 'Android 8.0以降が必要です'
                : 'このデバイスではPiPがサポートされていません',
          ),
          enabled: false,
        ),
      );
    }

    return SettingsCard(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('PiPモードを有効化'),
            subtitle: const Text('通話中にPiPモードに切り替えられます'),
            value: _isEnabled,
            onChanged: _togglePiP,
          ),
          if (_isEnabled)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                PlatformCompat.isAndroid
                    ? 'ホームボタンを押すとPiPモードに入ります'
                    : 'システムがPiPモードを管理します',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
