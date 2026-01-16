import 'package:flutter/material.dart';
import 'package:vagina/theme/app_theme.dart';

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
  final VoidCallback onManualSetup;
  final VoidCallback onBack;

  const AuthenticationScreen({
    super.key,
    required this.onManualSetup,
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
      id: 'x',
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
    // TODO: Implement actual authentication when backend is ready
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${provider.name}認証は準備中です'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'ログインして\nはじめましょう',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Authentication provider buttons
                    ..._providers.map((provider) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildProviderButton(
                            context,
                            provider,
                          ),
                        )),

                    const SizedBox(height: 32),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'または',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Manual setup button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onManualSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: const Text(
                          '自分で設定する',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Terms and privacy notice
                    Text(
                      '続行することで、利用規約とプライバシーポリシーに同意したものとみなされます',
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleProviderTap(context, provider),
        icon: Icon(provider.icon, size: 24),
        label: Text(
          '${provider.name}でログイン',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
