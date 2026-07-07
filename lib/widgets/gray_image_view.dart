import 'package:flutter/material.dart';

import '../core/image/gray_image.dart';

/// 4階調グレースケール画像をドット絵として描画する。
/// 送信プレビューと受信表示で共用。未受信の画素はブルーグレーで塗る。
class GrayImageView extends StatelessWidget {
  const GrayImageView({super.key, required this.image});

  final GrayImage image;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: image.width / image.height,
      child: CustomPaint(painter: _GrayImagePainter(image)),
    );
  }
}

class _GrayImagePainter extends CustomPainter {
  _GrayImagePainter(this.image);

  final GrayImage image;

  // レベル0〜3 → 黒・濃灰・淡灰・白
  static const _levelColors = [
    Color(0xFF000000),
    Color(0xFF555555),
    Color(0xFFAAAAAA),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / image.width;
    final cellH = size.height / image.height;

    // 未受信領域は階調と見分けが付く色にする
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.blueGrey.shade600,
    );

    final paints = [
      for (final color in _levelColors) Paint()..color = color,
    ];
    for (var i = 0; i < image.pixels.length; i++) {
      final x = i % image.width;
      final y = i ~/ image.width;
      // セル境界の隙間を防ぐため僅かに重ねて塗る
      canvas.drawRect(
        Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
        paints[image.pixels[i].clamp(0, kGrayLevels - 1)],
      );
    }
  }

  @override
  bool shouldRepaint(_GrayImagePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.image.pixels.length != image.pixels.length;
}
