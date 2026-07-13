import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 暗い地にイエロー発光の表示を置く「ディスプレイ」。
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
      decoration: BoxDecoration(
        color: GadgetColors.lcdBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    );
  }
}
