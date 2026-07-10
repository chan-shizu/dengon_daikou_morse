import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 押し込み感のある大型の物理ボタン風。送信/受信の主操作に使う。
class GadgetButton extends StatelessWidget {
  const GadgetButton({
    super.key,
    required this.label,
    this.subLabel,
    required this.icon,
    required this.onPressed,
    this.color = GadgetColors.amber,
  });

  final String label;

  /// 銘板の刻印風の英字サブラベル
  final String? subLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final face = enabled ? color : GadgetColors.ledOff;
    final onFace = enabled ? Colors.black : GadgetColors.bezelDark;

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(face, Colors.white, 0.15)!,
              face,
              Color.lerp(face, Colors.black, 0.25)!,
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GadgetColors.bezelDark, width: 2),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 3),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
                  fontWeight: FontWeight.w700,
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
