import '../image/gray_image.dart';
import 'morse_protocol.dart';

/// 4階調画像と送信ビット列（メタ17bit + 画素×2bit）の相互変換。
///
/// 画素レベル（0〜3）は MSB 先行の2ビットで送る。ビットは点滅で
/// 0=点（1単位ON）/ 1=線（3単位ON）として送るため、1 は 0 の2倍の
/// 時間がかかる。1 が過半のビット列は全ビット反転して送り
/// （2bit値では レベル → 3-レベル と等価）、メタの反転フラグで伝える。
class MorseImageCodec {
  /// 送信ビット列: [幅8bit][高さ8bit][反転1bit][画素 width*height*2 bit]
  static List<bool> encode(GrayImage image) {
    final pixelBits = <bool>[
      for (final level in image.pixels)
        for (var b = kGrayBitsPerPixel - 1; b >= 0; b--) (level >> b) & 1 == 1,
    ];
    final ones = pixelBits.where((bit) => bit).length;
    final inverted = ones * 2 > pixelBits.length;
    return [
      ..._toBits(image.width, kImageDimensionBits),
      ..._toBits(image.height, kImageDimensionBits),
      inverted,
      for (final bit in pixelBits) bit != inverted,
    ];
  }

  /// ペイロードの想定送信時間（プリアンブル・画像モード符号込み）
  static int transmissionMs(List<bool> payload, int unitMs) {
    var units = codeUnits(kPreambleCode) + 2 + codeUnits(kImageStartCode) + 2;
    for (final bit in payload) {
      units += bit ? 4 : 2;
    }
    return units * unitMs;
  }

  static List<bool> _toBits(int value, int bitCount) => [
        for (var i = bitCount - 1; i >= 0; i--) (value >> i) & 1 == 1,
      ];
}
