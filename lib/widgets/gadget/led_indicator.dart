import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// ラベル付きの LED ランプ。点灯時はグローで発光させる。
class LedIndicator extends StatelessWidget {
  const LedIndicator({
    super.key,
    required this.isOn,
    required this.label,
    this.onColor = GadgetColors.accent,
  });

  final bool isOn;

  /// 銘板の刻印ラベル（英字想定）
  final String label;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn ? onColor : GadgetColors.ledOff,
            border: Border.all(color: GadgetColors.ink, width: 1.5),
            boxShadow: isOn
                ? [BoxShadow(color: onColor.withValues(alpha: 0.7), blurRadius: 8)]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: GadgetTextStyles.plate),
      ],
    );
  }
}
