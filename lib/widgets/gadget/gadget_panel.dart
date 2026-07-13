import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// ステッカー風のセクションカード。
/// 白い面に太いアウトラインとオフセット影で背景から浮かせる。
class GadgetPanel extends StatelessWidget {
  const GadgetPanel({
    super.key,
    this.label,
    this.padding = const EdgeInsets.all(12),
    required this.child,
  });

  /// カードの見出しラベル（英字想定）
  final String? label;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GadgetColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GadgetColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: GadgetColors.ink, offset: Offset(0, 4)),
        ],
      ),
      padding: padding,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return label == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label!, style: GadgetTextStyles.plate),
              const SizedBox(height: 8),
              child,
            ],
          );
  }
}
