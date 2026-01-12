import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
    return SafeArea(
      child: Column(
        children: [
          // 戻るボタン
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
            ),
          ),

          Expanded(
            child: Center(
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
                  const Text(
                    '準備完了！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'これで、VAGINAを使い始める\n準備が整いました',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 64),

                  // 機能ポイント
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      children: [
                        _buildFeaturePoint(
                          '声で思考を整理',
                          Icons.record_voice_over,
                        ),
                        const SizedBox(height: 16),
                        _buildFeaturePoint(
                          'AIと自然な会話',
                          Icons.psychology,
                        ),
                        const SizedBox(height: 16),
                        _buildFeaturePoint(
                          'アイデアを即座に記録',
                          Icons.lightbulb,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 64),

                  // 円形スタートボタン（通話ボタンをオマージュ）
                  _StartButton(onPressed: widget.onStart),
                ],
              ),
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

/// 円形スタートボタン - ホーム画面の通話ボタンとモーフィングできるデザイン
class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const _StartButton({required this.onPressed});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 大きな円形FAB
        SizedBox(
          width: 80,
          height: 80,
          child: FloatingActionButton(
            heroTag: 'start_call_fab',
            onPressed: onPressed,
            backgroundColor: AppTheme.successColor,
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.phone,
              size: 36,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // キャプション
        Text(
          'はじめる',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.9),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
