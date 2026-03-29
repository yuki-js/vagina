import 'package:flutter/material.dart';
import 'package:vagina/feat/filebrowser/screens/file_browser.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Features grid tab
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: GridView.count(
          crossAxisCount: 4,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 24,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
          children: [
            _FeaturePlaceholder(
              icon: Icons.folder,
              label: l10n.fileBrowserRootTitle,
              color: Colors.amber,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FileBrowserScreen(),
                  ),
                );
              },
            ),
            _FeaturePlaceholder(
              icon: Icons.storefront,
              label: l10n.homeMoreFeatureWazaMachine,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _FeaturePlaceholder({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.homeMoreFeatureComingSoon(label)),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.8),
                    color.withValues(alpha: 0.4),
                  ],
                ).createShader(bounds),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
