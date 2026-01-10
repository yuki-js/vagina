import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Permission item configuration
class PermissionItem {
  final String title;
  final String description;
  final IconData icon;
  final bool isRequired;
  final bool isGranted;

  const PermissionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.isRequired,
    required this.isGranted,
  });
}

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
  // Permission states
  bool _microphoneGranted = false;
  bool _notificationsGranted = false;
  bool _storageGranted = false;

  void _handlePermissionRequest(String permissionType) {
    // TODO: Implement actual permission request
    setState(() {
      switch (permissionType) {
        case 'microphone':
          _microphoneGranted = true;
          break;
        case 'notifications':
          _notificationsGranted = true;
          break;
        case 'storage':
          _storageGranted = true;
          break;
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permissionTypeの権限が許可されました'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<PermissionItem> get _permissions => [
        PermissionItem(
          title: 'マイク',
          description: '音声での会話に必要です',
          icon: Icons.mic,
          isRequired: true,
          isGranted: _microphoneGranted,
        ),
        PermissionItem(
          title: '通知',
          description: 'AIからの応答やヒントを受け取ります',
          icon: Icons.notifications,
          isRequired: false,
          isGranted: _notificationsGranted,
        ),
        PermissionItem(
          title: 'ストレージ',
          description: '会話履歴やメモを保存します',
          icon: Icons.storage,
          isRequired: false,
          isGranted: _storageGranted,
        ),
      ];

  bool get _canContinue {
    // Can continue if all required permissions are granted
    return _permissions
        .where((p) => p.isRequired)
        .every((p) => p.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Back button
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 50,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    '権限の設定',
                    textAlign: TextAlign.center,
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
                    textAlign: TextAlign.center,
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
                        child: _buildPermissionCard(permission),
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
                  TextButton(
                    onPressed: widget.onContinue,
                    child: Text(
                      'あとで設定する',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(PermissionItem permission) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: permission.isGranted
              ? AppTheme.successColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: permission.isGranted
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : AppTheme.primaryColor.withValues(alpha: 0.2),
            ),
            child: Icon(
              permission.isGranted ? Icons.check : permission.icon,
              color: permission.isGranted
                  ? AppTheme.successColor
                  : AppTheme.primaryColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      permission.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (permission.isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '必須',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  permission.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Action button
          if (!permission.isGranted)
            OutlinedButton(
              onPressed: () => _handlePermissionRequest(
                permission.title == 'マイク'
                    ? 'microphone'
                    : permission.title == '通知'
                        ? 'notifications'
                        : 'storage',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '許可',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
