import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/typography.dart';

/// One labelled volume row: a label, a slider from 0 to 1, and a percentage.
///
/// The same widget is used three times on the settings screen and again in
/// compact form inside the pause overlay, so volume can be changed mid fight.
class VolumeSlider extends StatelessWidget {
  const VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.compact = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 62 : 88,
              child: Text(
                label,
                style: compact ? AppType.hudSmall : AppType.body,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: compact ? 2 : 4,
                  activeTrackColor: Palette.uiAccent,
                  inactiveTrackColor: Palette.uiPanelLight,
                  thumbColor: Palette.uiAccent,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: compact ? 6 : 8,
                  ),
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: enabled ? onChanged : null,
                  onChangeEnd: enabled ? onChangeEnd : null,
                ),
              ),
            ),
            SizedBox(
              width: compact ? 38 : 48,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: compact ? AppType.hudSmall : AppType.bodyDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
