import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 送信画像の階調数（2bit = 4階調）
const int kGrayLevels = 4;

/// 1画素あたりの送信ビット数
const int kGrayBitsPerPixel = 2;

/// 画像送信の画質（長辺の画素数）。画素数がそのまま送信時間に効く
enum GrayImageQuality {
  low('低', 24),
  medium('中', 32),
  high('高', 48);

  const GrayImageQuality(this.label, this.longSide);

  final String label;
  final int longSide;
}

/// 4階調グレースケール画像。[pixels] は左上から行順で 0（黒）〜3（白）。
/// 受信途中は pixels.length < width * height の部分画像になり得る。
class GrayImage {
  const GrayImage({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;
  final List<int> pixels;

  int get pixelCount => width * height;
  bool get isComplete => pixels.length >= pixelCount;
}

/// 画像バイト列を縮小し、Floyd–Steinberg ディザで4階調化する。
/// デコードできないデータの場合は null。
GrayImage? convertToGrayImage(Uint8List bytes, GrayImageQuality quality) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  decoded = img.bakeOrientation(decoded);

  final resized = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: quality.longSide)
      : img.copyResize(decoded, height: quality.longSide);

  final w = resized.width;
  final h = resized.height;
  // 輝度（0〜255）を誤差拡散のため浮動小数で保持
  final gray = List<double>.generate(
    w * h,
    (i) => img.getLuminance(resized.getPixel(i % w, i ~/ w)).toDouble(),
  );

  // 階調間の輝度幅（4階調なら 85）
  const step = 255 / (kGrayLevels - 1);

  final pixels = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final level = (gray[i] / step).round().clamp(0, kGrayLevels - 1);
      pixels[i] = level;
      final error = gray[i] - level * step;
      if (x + 1 < w) gray[i + 1] += error * 7 / 16;
      if (y + 1 < h) {
        if (x > 0) gray[i + w - 1] += error * 3 / 16;
        gray[i + w] += error * 5 / 16;
        if (x + 1 < w) gray[i + w + 1] += error * 1 / 16;
      }
    }
  }
  return GrayImage(width: w, height: h, pixels: pixels);
}
