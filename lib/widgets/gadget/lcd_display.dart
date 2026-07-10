import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 凹んだベゼルの中にアンバー発光の表示を置く「液晶画面」。
/// うっすらと走査線を重ねてブラウン管/LCD の質感を出す。
class LcdDisplay extends StatelessWidget {
  const LcdDisplay({
    super.key,
    this.padding = const EdgeInsets.all(12),
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 左上を暗くするグラデーション縁で「彫り込まれた」画面に見せる
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GadgetColors.bezelDark, GadgetColors.bezelLight],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: GadgetColors.lcdBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(padding: padding, child: child),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ScanlinePainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => false;
}
