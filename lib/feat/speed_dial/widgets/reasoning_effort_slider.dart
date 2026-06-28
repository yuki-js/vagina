import 'package:flutter/material.dart';
import 'package:vagina/core/theme/app_theme.dart';
import 'package:vagina/l10n/app_localizations.dart';
import 'package:vagina/models/speed_dial.dart';

class ReasoningEffortSlider extends StatelessWidget {
  final SpeedDialReasoningEffort value;
  final ValueChanged<SpeedDialReasoningEffort> onChanged;

  const ReasoningEffortSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = SpeedDialReasoningEffort.values;
    final selectedIndex = values.indexOf(value);
    final labels = values
        .map((effort) => _label(l10n, effort))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: AppTheme.lightTextSecondary.withValues(
              alpha: 0.18,
            ),
            thumbColor: AppTheme.primaryColor,
            activeTickMarkColor: AppTheme.primaryColor.withValues(alpha: 0.9),
            inactiveTickMarkColor: AppTheme.lightTextSecondary.withValues(
              alpha: 0.28,
            ),
          ),
          child: Slider(
            value: selectedIndex.toDouble(),
            min: 0,
            max: (labels.length - 1).toDouble(),
            divisions: labels.length - 1,
            onChanged: (nextValue) => onChanged(values[nextValue.round()]),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: index == selectedIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: index == selectedIndex
                          ? AppTheme.lightTextPrimary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _label(AppLocalizations l10n, SpeedDialReasoningEffort effort) {
    return switch (effort) {
      SpeedDialReasoningEffort.off => l10n.speedDialConfigReasoningEffortOff,
      SpeedDialReasoningEffort.minimal =>
        l10n.speedDialConfigReasoningEffortMinimal,
      SpeedDialReasoningEffort.low => l10n.speedDialConfigReasoningEffortLow,
      SpeedDialReasoningEffort.medium =>
        l10n.speedDialConfigReasoningEffortMedium,
      SpeedDialReasoningEffort.high => l10n.speedDialConfigReasoningEffortHigh,
      SpeedDialReasoningEffort.xhigh =>
        l10n.speedDialConfigReasoningEffortXhigh,
    };
  }
}
