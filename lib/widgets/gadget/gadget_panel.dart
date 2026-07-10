import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 面取りベゼル付きのセクションパネル。
/// 上・左を明るく、下・右を暗くして筐体から盛り上がって見せる。
class GadgetPanel extends StatelessWidget {
  const GadgetPanel({
    super.key,
    this.label,
    this.padding = const EdgeInsets.all(12),
    required this.child,
  });

  /// 銘板風の刻印ラベル（英字想定）
  final String? label;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 左上→右下のグラデーション縁で面取りベゼルを表現する
      // （角丸では辺ごとの Border 色分けが使えないため）
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GadgetColors.bezelLight, GadgetColors.bezelDark],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: GadgetColors.panel,
          borderRadius: BorderRadius.circular(6.5),
        ),
        padding: padding,
        child: _buildContent(),
      ),
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
