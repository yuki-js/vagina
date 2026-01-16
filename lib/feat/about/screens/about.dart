import 'package:flutter/material.dart';
import 'package:vagina/theme/app_theme.dart';
import 'constellation_game.dart';
import 'voice_visualizer_game.dart';

/// About page with app information and philosophy
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _tapCount = 0;
  static const int _requiredTaps = 7;
  int _easterEggIndex = 0; // Alternates between easter eggs

  void _handleTitleTap() {
    setState(() {
      _tapCount++;
    });

    if (_tapCount >= _requiredTaps) {
      // Reset counter and navigate to hidden easter egg
      setState(() {
        _tapCount = 0;
      });
      
      // Alternate between the two easter eggs
      final easterEgg = _easterEggIndex % 2 == 0
          ? const ConstellationGameScreen()
          : const VoiceVisualizerGameScreen();
      
      _easterEggIndex++;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => easterEgg,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.lightBackgroundGradient,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Title with hidden easter egg trigger
                    GestureDetector(
                      onTap: _handleTitleTap,
                      child: Text(
                        'VAGINA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Voice AGI Notepad Agent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.lightTextSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Main content
                    _buildSection(
                      icon: Icons.voice_chat,
                      title: 'あなたの声を、思考へ',
                      content: 'VAGINAは単なる音声アシスタントではありません。'
                          'あなたの言葉を受け止め、理解し、共に考えるパートナーです。',
                    ),
                    const SizedBox(height: 32),
                    
                    _buildSection(
                      icon: Icons.lightbulb_outline,
                      title: 'アイデアの生まれる場所',
                      content: '会話の中で生まれたアイデアは、その場で整理され、'
                          'ノートパッドとして記録されます。思考の流れを止めることなく、'
                          'あなたのクリエイティビティを最大限に引き出します。',
                    ),
                    const SizedBox(height: 32),
                    
                    _buildSection(
                      icon: Icons.auto_awesome,
                      title: 'AGI時代の新しい体験',
                      content: '高度なAI技術により、まるで人間と話しているかのような'
                          '自然な会話が実現します。質問に答えるだけでなく、'
                          'あなたの意図を汲み取り、最適な支援を提供します。',
                    ),
                    const SizedBox(height: 48),
                    
                    // Footer
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: AppTheme.errorColor,
                            size: 32,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'あなたの創造性を解き放つために',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'VAGINAは、声とAIの力で、\n新しい可能性への扉を開きます。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // App info section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.lightSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow('バージョン', '1.0.0'),
                          const Divider(height: 24),
                          _buildInfoRow('Powered by', 'Azure OpenAI Realtime API'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}
