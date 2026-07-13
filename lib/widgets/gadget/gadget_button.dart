import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// ステッカー風の大型ボタン。送信/受信の主操作に使う。
class GadgetButton extends StatelessWidget {
  const GadgetButton({
    super.key,
    required this.label,
    this.subLabel,
    required this.icon,
    required this.onPressed,
    this.color = GadgetColors.accent,
  });

  final String label;

  /// 英字のサブラベル
  final String? subLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final face = enabled ? color : GadgetColors.ledOff;
    final onFace = enabled ? GadgetColors.ink : GadgetColors.label;

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GadgetColors.ink, width: 2),
          boxShadow: enabled
              ? const [
                  BoxShadow(color: GadgetColors.ink, offset: Offset(0, 4)),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: onFace, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: onFace,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              if (subLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  subLabel!,
                  style: TextStyle(
                    color: onFace.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
