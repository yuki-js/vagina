import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A stylish microphone gain slider with visual feedback
class MicGainSlider extends StatelessWidget {
  /// The current gain value (0.0 to 1.0)
  final double value;

  /// Called when the value changes
  final ValueChanged<double>? onChanged;

  /// Whether the microphone is muted
  final bool isMuted;

  const MicGainSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isMuted ? Icons.mic_off : Icons.mic,
            color: isMuted ? AppTheme.errorColor : AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                activeTrackColor:
                    isMuted ? AppTheme.textSecondary : AppTheme.primaryColor,
                inactiveTrackColor: AppTheme.surfaceColor,
                thumbColor:
                    isMuted ? AppTheme.textSecondary : AppTheme.primaryColor,
              ),
              child: Slider(
                value: value,
                onChanged: isMuted ? null : onChanged,
                min: 0.0,
                max: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: isMuted ? AppTheme.textSecondary : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
