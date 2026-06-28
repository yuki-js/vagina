import 'package:flutter/material.dart';
import 'package:vagina/feat/announcement/services/announcement_service.dart';
import 'package:vagina/feat/announcement/widgets/home_announcement_host.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Authentication provider configuration
class AuthProvider {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const AuthProvider({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Second OOBE screen - Authentication options
class AuthenticationScreen extends StatelessWidget {
  final AnnouncementService announcementService;
  final Future<void> Function(AuthProvider provider) onProviderTap;
  final bool isAuthenticating;
  final VoidCallback onBack;

  const AuthenticationScreen({
    super.key,
    required this.announcementService,
    required this.onProviderTap,
    this.isAuthenticating = false,
    required this.onBack,
  });

  // Predefined authentication providers
  // In the future, this could be loaded from an external configuration file
  static const List<AuthProvider> _providers = [
    AuthProvider(
      id: 'google',
      name: 'Google',
      icon: Icons.g_mobiledata,
      color: Color(0xFF4285F4),
    ),
    AuthProvider(
      id: 'github',
      name: 'GitHub',
      icon: Icons.code,
      color: Color(0xFF181717),
    ),
    AuthProvider(
      id: 'twitter',
      name: 'X (Twitter)',
      icon: Icons.close, // X symbol
      color: Color(0xFF000000),
    ),
    AuthProvider(
      id: 'apple',
      name: 'Apple',
      icon: Icons.apple,
      color: Color(0xFF000000),
    ),
  ];

  void _handleProviderTap(BuildContext context, AuthProvider provider) {
    onProviderTap(provider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      l10n.oobeAuthenticationTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: HomeAnnouncementHost(service: announcementService),
                    ),

                    const SizedBox(height: 24),

                    // Authentication provider buttons
                    ..._providers.map(
                      (provider) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildProviderButton(context, provider),
                      ),
                    ),

                    if (isAuthenticating) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.oobeAuthenticationSigningIn,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Terms and privacy notice
                    Text(
                      l10n.oobeAuthenticationTermsNotice,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.5,
                      ),
                    ),
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
              onPressed: onBack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderButton(BuildContext context, AuthProvider provider) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isAuthenticating
            ? null
            : () => _handleProviderTap(context, provider),
        icon: Icon(provider.icon, size: 24),
        label: Text(
          l10n.oobeAuthenticationProviderButton(provider.name),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: provider.color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
