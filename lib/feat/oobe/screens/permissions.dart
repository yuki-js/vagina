import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vagina/theme/app_theme.dart';
import 'package:vagina/data/permission_manager.dart';
import 'package:vagina/feat/oobe/widgets/permission_card.dart';


/// Fourth OOBE screen - Permissions and preferences setup
class PermissionsScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const PermissionsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final PermissionManager _permissionManager = PermissionManager();
  
  late List<PermissionItem> _permissions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    // Check current permission states
    final micStatus = await Permission.microphone.status;
    final storageGranted = await _permissionManager.hasStoragePermission();

    if (mounted) {
      setState(() {
        _permissions = [
          PermissionItem(
            title: 'マイク',
            description: '音声での会話に必要です',
            icon: Icons.mic,
            isRequired: true,
            isGranted: micStatus.isGranted,
          ),
          PermissionItem(
            title: 'ストレージ',
            description: '会話履歴やメモを保存します',
            icon: Icons.storage,
            isRequired: false,
            isGranted: storageGranted,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePermissionRequest(PermissionItem permission) async {
    bool granted = false;

    try {
      if (permission.title == 'マイク') {
        final status = await Permission.microphone.request();
        granted = status.isGranted;
        
        if (status.isPermanentlyDenied) {
          _showSettingsDialog('マイク');
          return;
        }
      } else if (permission.title == 'ストレージ') {
        granted = await _permissionManager.requestStoragePermission();
        
        if (!granted) {
          final status = await Permission.storage.status;
          if (status.isPermanentlyDenied) {
            _showSettingsDialog('ストレージ');
            return;
          }
        }
      }

      setState(() {
        permission.isGranted = granted;
      });

      if (granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${permission.title}の権限が許可されました'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('権限の要求に失敗しました: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightSurfaceColor,
        title: Text('$permissionName権限が必要です'),
        content: Text(
          '$permissionName権限が拒否されています。設定から権限を有効にしてください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }

  bool get _canContinue {
    return _permissions
        .where((p) => p.isRequired)
        .every((p) => p.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return SafeArea(
      child: Stack(
        children: [
          // メインコンテンツ - 中央寄せ
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      '権限の設定',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'VAGINAを最大限に活用するために、\nいくつかの権限が必要です',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Permission items
                    ..._permissions.map((permission) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PermissionCard(
                            permission: permission,
                            onRequest: () => _handlePermissionRequest(permission),
                          ),
                        )),

                    const SizedBox(height: 32),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canContinue ? widget.onContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.1),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '続ける',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    if (!_canContinue) ...[
                      const SizedBox(height: 12),
                      Text(
                        '※必須の権限を許可してください',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warningColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Skip button
                    Center(
                      child: TextButton(
                        onPressed: widget.onContinue,
                        child: Text(
                          'あとで設定する',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // 戻るボタン - 常に左上に固定
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
          ),
        ],
      ),
    );
  }
}
