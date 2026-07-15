import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vagina/feat/speed_dial/state/speed_dial_providers.dart';
import 'package:vagina/models/speed_dial.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/utils/call_navigation_utils.dart';
import 'package:vagina/feat/speed_dial/screens/config.dart';
import 'package:vagina/l10n/app_localizations.dart';

/// Speed dial tab - shows saved character presets for quick call start
class SpeedDialTab extends ConsumerWidget {
  const SpeedDialTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final speedDialsAsync = ref.watch(speedDialsProvider);

    return speedDialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text(l10n.speedDialTabLoadError(error.toString()))),
      data: (speedDials) {
        if (speedDials.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildTabPanel(
          context,
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                l10n.homeTabSpeedDial,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.speedDialTabSubtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              // Speed dial grid with fixed-size cards
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate number of columns based on screen width
                  // Each card should be approximately 160px wide
                  final cardWidth = 160.0;
                  final crossAxisCount = (constraints.maxWidth / cardWidth)
                      .floor()
                      .clamp(2, 6);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: speedDials.length,
                    itemBuilder: (context, index) {
                      final speedDial = speedDials[index];
                      return _buildSpeedDialCard(context, ref, speedDial);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return _buildTabPanel(
      context,
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            AppLocalizations.of(context).homeTabSpeedDial,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).speedDialTabSubtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 100),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_border,
                  size: 64,
                  color: AppTheme.lightTextSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).speedDialTabEmptyTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).speedDialTabEmptyBody,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPanel(BuildContext context, Widget child) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            left: false,
            child: FloatingActionButton(
              heroTag: 'speed_dial_add_fab',
              shape: const CircleBorder(),
              onPressed: () => _addSpeedDial(context),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedDialCard(
    BuildContext context,
    WidgetRef ref,
    SpeedDial speedDial,
  ) {
    final isDefault = speedDial.isDefault;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _startCall(context, ref, speedDial),
        onLongPress: () => _editSpeedDial(context, speedDial),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon/Emoji - Brand logo for default, emoji for custom
              if (isDefault)
                SvgPicture.asset(
                  'assets/icons/web/favicon-transparent-primary.svg',
                  width: 48,
                  height: 48,
                  semanticsLabel: speedDial.name,
                )
              else
                Text(
                  speedDial.iconEmoji ?? '⭐',
                  style: const TextStyle(fontSize: 48),
                ),
              const SizedBox(height: 12),
              // Name
              Text(
                speedDial.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightTextPrimary,
                ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              if (speedDial.description != null &&
                  speedDial.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  speedDial.description!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTextSecondary,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addSpeedDial(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SpeedDialConfigScreen()),
    );
  }

  Future<void> _startCall(
    BuildContext context,
    WidgetRef ref,
    SpeedDial speedDial,
  ) async {
    await CallNavigationUtils.navigateToCallWithSpeedDial(
      context: context,
      speedDial: speedDial,
    );
  }

  Future<void> _editSpeedDial(BuildContext context, SpeedDial speedDial) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpeedDialConfigScreen(speedDial: speedDial),
      ),
    );
  }
}
