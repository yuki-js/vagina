import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vagina/api/generated/models/list_oidc_providers_success_body_item.dart'
    as api_model;
import 'package:vagina/core/config/constants.dart';
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

  factory AuthProvider.fromApi(
    api_model.ListOidcProvidersSuccessBodyItem provider,
  ) {
    return switch (provider.id) {
      'github' => AuthProvider(
        id: provider.id,
        name: provider.displayName,
        icon: Icons.code,
        color: const Color(0xFF181717),
      ),
      'harigata' => AuthProvider(
        id: provider.id,
        name: provider.displayName,
        icon: Icons.vpn_key,
        color: const Color(0xFF5E35B1),
      ),
      _ => AuthProvider(
        id: provider.id,
        name: provider.displayName,
        icon: Icons.login,
        color: const Color(0xFF455A64),
      ),
    };
  }
}

/// Second OOBE screen - Authentication options
class AuthenticationScreen extends StatelessWidget {
  static final Uri _termsOfServiceUrl = Uri.parse(Constants.termsOfServiceUrl);
  static final Uri _privacyPolicyUrl = Uri.parse(Constants.privacyPolicyUrl);

  final AnnouncementService announcementService;
  final List<AuthProvider> providers;
  final bool isLoadingProviders;
  final String? providerLoadError;
  final Future<void> Function(AuthProvider provider) onProviderTap;
  final bool isAuthenticating;
  final VoidCallback onRetryLoadProviders;
  final VoidCallback onBack;
  final Future<bool> Function(Uri url) openLegalDocument;

  const AuthenticationScreen({
    super.key,
    required this.announcementService,
    required this.providers,
    this.isLoadingProviders = false,
    this.providerLoadError,
    required this.onProviderTap,
    this.isAuthenticating = false,
    required this.onRetryLoadProviders,
    required this.onBack,
    Future<bool> Function(Uri url)? openLegalDocument,
  }) : openLegalDocument = openLegalDocument ?? _openLegalDocument;

  static Future<bool> _openLegalDocument(Uri url) {
    return launchUrl(url, mode: LaunchMode.platformDefault);
  }

  void _handleProviderTap(BuildContext context, AuthProvider provider) {
    onProviderTap(provider);
  }

  Future<void> _handleLegalDocumentTap(Uri url) async {
    try {
      await openLegalDocument(url);
    } on Exception {
      // A browser launch failure must not interrupt or crash authentication.
    }
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

                    _buildProviderArea(context),

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
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.oobeAuthenticationTermsNoticePrefix,
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _LegalDocumentLink(
                              label: l10n.oobeAuthenticationTermsOfServiceLink,
                              onTap: () =>
                                  _handleLegalDocumentTap(_termsOfServiceUrl),
                            ),
                          ),
                          TextSpan(
                            text:
                                l10n.oobeAuthenticationTermsNoticeBetweenLinks,
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _LegalDocumentLink(
                              label: l10n.oobeAuthenticationPrivacyPolicyLink,
                              onTap: () =>
                                  _handleLegalDocumentTap(_privacyPolicyUrl),
                            ),
                          ),
                          TextSpan(
                            text: l10n.oobeAuthenticationTermsNoticeSuffix,
                          ),
                        ],
                      ),
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

  Widget _buildProviderArea(BuildContext context) {
    if (isLoadingProviders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final error = providerLoadError;
    if (error != null) {
      return _ProviderStateMessage(
        icon: Icons.error_outline,
        message: error,
        actionLabel: 'Retry',
        onAction: onRetryLoadProviders,
      );
    }

    if (providers.isEmpty) {
      return const _ProviderStateMessage(
        icon: Icons.no_accounts,
        message: 'No sign-in providers are configured for this server.',
      );
    }

    return Column(
      children: providers
          .map(
            (provider) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildProviderButton(context, provider),
            ),
          )
          .toList(growable: false),
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

class _ProviderStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ProviderStateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 32),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalDocumentLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LegalDocumentLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.85),
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 12,
          height: 1.5,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(label),
    );
  }
}
