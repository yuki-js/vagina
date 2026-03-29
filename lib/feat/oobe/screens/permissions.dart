import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/data/permission_manager.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/feat/oobe/widgets/permission_card.dart';
import 'package:vagina/l10n/app_localizations.dart';

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
  Locale? _lastInitializedLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locale = Localizations.localeOf(context);
    if (_lastInitializedLocale != locale) {
      _lastInitializedLocale = locale;
      _initializePermissions();
    }
  }

  Future<void> _initializePermissions() async {
    final l10n = AppLocalizations.of(context);

    // Check current permission states
    final micStatus = await Permission.microphone.status;
    final storageGranted = await _permissionManager.hasStoragePermission();

    if (mounted) {
      setState(() {
        _permissions = [
          PermissionItem(
            title: l10n.permissionsMicrophoneTitle,
            description: l10n.permissionsMicrophoneDescription,
            icon: Icons.mic,
            isRequired: true,
            isGranted: micStatus.isGranted,
          ),
          PermissionItem(
            title: l10n.permissionsStorageTitle,
            description: l10n.permissionsStorageDescription,
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
    final l10n = AppLocalizations.of(context);
    bool granted = false;

    try {
      if (permission.icon == Icons.mic) {
        final status = await Permission.microphone.request();
        granted = status.isGranted;

        if (status.isPermanentlyDenied) {
          _showSettingsDialog(permission.title);
          return;
        }
      } else if (permission.icon == Icons.storage) {
        granted = await _permissionManager.requestStoragePermission();

        if (!granted) {
          final status = await Permission.storage.status;
          if (status.isPermanentlyDenied) {
            _showSettingsDialog(permission.title);
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
            content: Text(l10n.permissionsGranted(permission.title)),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.permissionsRequestFailed(e.toString())),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showSettingsDialog(String permissionName) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightSurfaceColor,
        title: Text(l10n.permissionsSettingsDialogTitle(permissionName)),
        content: Text(l10n.permissionsSettingsDialogBody(permissionName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.permissionsDialogCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
            child: Text(l10n.permissionsOpenSettings),
          ),
        ],
      ),
    );
  }

  bool get _canContinue {
    return _permissions.where((p) => p.isRequired).every((p) => p.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                    Text(
                      l10n.permissionsScreenTitle,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      l10n.permissionsIntro(AppConfig.appName),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Permission items
                    ..._permissions.map(
                      (permission) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PermissionCard(
                          permission: permission,
                          onRequest: () => _handlePermissionRequest(permission),
                          requiredLabel: l10n.permissionsRequiredBadge,
                          requestLabel: l10n.permissionsAllow,
                        ),
                      ),
                    ),

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
                        child: Text(
                          l10n.permissionsContinue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    if (!_canContinue) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.permissionsRequiredHint,
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
                          l10n.permissionsConfigureLater,
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
