import 'package:flutter/material.dart';
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// OOBE 最終画面 - 準備完了
class DiveInScreen extends StatefulWidget {
  final VoidCallback onStart;
  final VoidCallback onBack;

  const DiveInScreen({
    super.key,
    required this.onStart,
    required this.onBack,
  });

  @override
  State<DiveInScreen> createState() => _DiveInScreenState();
}

class _DiveInScreenState extends State<DiveInScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // アニメーションチェックマーク
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.successColor,
                                  AppTheme.successColor.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.7, 1.0],
                              ),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // メインメッセージ
                    Text(
                      l10n.diveInTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      l10n.diveInReady(AppConfig.appName),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 64),

                    // 機能ポイント
                    Column(
                      children: [
                        _buildFeaturePoint(
                          l10n.diveInFeatureOrganizeThoughts,
                          Icons.record_voice_over,
                        ),
                        const SizedBox(height: 16),
                        _buildFeaturePoint(
                          l10n.diveInFeatureNaturalAiConversation,
                          Icons.psychology,
                        ),
                        const SizedBox(height: 16),
                        _buildFeaturePoint(
                          l10n.diveInFeatureCaptureIdeas,
                          Icons.lightbulb,
                        ),
                      ],
                    ),

                    const SizedBox(height: 64),

                    // 円形スタートボタン - インラインで記述（モーフィング対応）
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: FloatingActionButton(
                        heroTag: 'call_fab',
                        onPressed: widget.onStart,
                        backgroundColor: AppTheme.successColor,
                        elevation: 8,
                        shape: const CircleBorder(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 28,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.diveInStart,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
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
              onPressed: widget.onBack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePoint(String text, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 24,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
