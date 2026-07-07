import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/core/image/gray_image.dart';
import 'package:dengon_daikou_morse/core/morse/morse_decoder.dart';
import 'package:dengon_daikou_morse/core/morse/morse_image_codec.dart';
import 'package:dengon_daikou_morse/core/morse/morse_protocol.dart';
import 'package:image/image.dart' as img;

const _unitMs = 200;

/// 画像送信仕様どおりの SignalEvent 列を組み立てる
List<SignalEvent> _imageEvents(List<bool> payload, {int unitMs = _unitMs}) {
  final events = <SignalEvent>[];
  var offMs = 100 * unitMs; // 送信開始前の暗闇

  void pulse(int onMs) {
    events.add(SignalEvent(isOn: true, durationMs: offMs));
    events.add(SignalEvent(isOn: false, durationMs: onMs));
    offMs = unitMs;
  }

  void code(String code) {
    for (final symbol in code.split('')) {
      pulse((symbol == '.' ? 1 : 3) * unitMs);
    }
    offMs = 3 * unitMs;
  }

  code(kPreambleCode);
  code(kImageStartCode);
  for (final bit in payload) {
    pulse((bit ? 3 : 1) * unitMs);
  }
  return events;
}

MorseDecoder _decode(List<SignalEvent> events) {
  final decoder = MorseDecoder(onCharacter: (_) {});
  events.forEach(decoder.onSignal);
  return decoder;
}

void main() {
  group('MorseImageCodec', () {
    test('メタ17bit + 画素2bit（MSB先行）でエンコードされる', () {
      // 4x2、レベルは 0 寄り → 反転なし
      const image = GrayImage(
        width: 4,
        height: 2,
        pixels: [3, 0, 0, 0, 1, 0, 2, 0],
      );
      final payload = MorseImageCodec.encode(image);

      expect(payload.length, kImageMetaBits + 8 * kGrayBitsPerPixel);
      // 幅=4 (00000100)、高さ=2 (00000010)、反転=false
      expect(payload.sublist(0, 8),
          [false, false, false, false, false, true, false, false]);
      expect(payload.sublist(8, 16),
          [false, false, false, false, false, false, true, false]);
      expect(payload[16], false);
      // 画素: 3=11, 0=00, 1=01, 2=10
      expect(payload.sublist(17, 17 + 8), [
        true, true, false, false, false, false, false, false, //
      ]);
      expect(payload.sublist(17 + 8), [
        false, true, false, false, true, false, false, false, //
      ]);
    });

    test('1が過半のビット列は反転して送信時間を短縮する', () {
      // 全画素レベル3（白）→ 画素ビットが全部 1 → 反転
      const image = GrayImage(width: 2, height: 2, pixels: [3, 3, 3, 2]);
      final payload = MorseImageCodec.encode(image);

      expect(payload[16], true); // 反転フラグ
      // 3=11→00、2=10→01
      expect(payload.sublist(17), [
        false, false, false, false, false, false, false, true, //
      ]);
    });

    test('想定送信時間は線が多いほど長い', () {
      final darkMs =
          MorseImageCodec.transmissionMs(List.filled(100, false), _unitMs);
      final brightMs =
          MorseImageCodec.transmissionMs(List.filled(100, true), _unitMs);
      expect(brightMs, greaterThan(darkMs));
    });
  });

  group('MorseDecoder（画像モード）', () {
    test('4階調画像をデコードして完了する', () {
      const image = GrayImage(
        width: 4,
        height: 3,
        pixels: [
          0, 1, 2, 3, //
          3, 2, 1, 0, //
          0, 2, 0, 1, //
        ],
      );
      final decoder = _decode(_imageEvents(MorseImageCodec.encode(image)));

      expect(decoder.phase, ReceivePhase.done);
      final received = decoder.image!;
      expect(received.width, 4);
      expect(received.height, 3);
      expect(received.pixels, image.pixels);
    });

    test('反転フラグ付きでも元の階調に復元される', () {
      // 白寄り → エンコード時に反転される
      const image = GrayImage(width: 2, height: 2, pixels: [3, 3, 2, 3]);
      final decoder = _decode(_imageEvents(MorseImageCodec.encode(image)));
      expect(decoder.image!.pixels, image.pixels);
    });

    test('受信途中は部分画像として取り出せる', () {
      const image = GrayImage(
        width: 4,
        height: 2,
        pixels: [0, 1, 2, 3, 3, 2, 1, 0],
      );
      final events = _imageEvents(MorseImageCodec.encode(image));
      // 末尾の3画素+1bit（7ビット = 7イベントペア）手前で打ち切る
      final partial = events.sublist(0, events.length - 14);

      final decoder = _decode(partial);
      expect(decoder.phase, ReceivePhase.receivingImagePixels);
      expect(decoder.receivedPixelCount, 4);
      expect(decoder.image!.pixels, image.pixels.sublist(0, 4));
      expect(decoder.image!.isComplete, false);
    });

    test('単位時間が異なっても自動校正で復元できる', () {
      const image = GrayImage(width: 3, height: 1, pixels: [3, 0, 2]);
      final decoder = _decode(
        _imageEvents(MorseImageCodec.encode(image), unitMs: 80),
      );
      expect(decoder.phase, ReceivePhase.done);
      expect(decoder.image!.pixels, image.pixels);
    });

    test('幅または高さが 0 のメタデータでは打ち切る', () {
      final payload = List<bool>.filled(kImageMetaBits, false); // 幅0・高さ0
      final decoder = _decode(_imageEvents(payload));
      expect(decoder.phase, ReceivePhase.done);
      expect(decoder.image, isNull);
    });
  });

  group('convertToGrayImage', () {
    Uint8List pngOf(img.Image source) => img.encodePng(source);

    test('真っ黒な画像は全画素レベル0になる', () {
      final source = img.Image(width: 64, height: 48);
      img.fill(source, color: img.ColorRgb8(0, 0, 0));

      final gray = convertToGrayImage(pngOf(source), GrayImageQuality.medium)!;
      expect(gray.width, GrayImageQuality.medium.longSide);
      expect(gray.height, 24); // アスペクト比 4:3 を維持
      expect(gray.pixels.every((p) => p == 0), true);
    });

    test('真っ白な画像は全画素レベル3になる', () {
      final source = img.Image(width: 32, height: 32);
      img.fill(source, color: img.ColorRgb8(255, 255, 255));

      final gray = convertToGrayImage(pngOf(source), GrayImageQuality.low)!;
      expect(gray.width, GrayImageQuality.low.longSide);
      expect(gray.pixels.every((p) => p == kGrayLevels - 1), true);
    });

    test('中間グレーは中間階調になる', () {
      final source = img.Image(width: 32, height: 32);
      img.fill(source, color: img.ColorRgb8(128, 128, 128));

      final gray = convertToGrayImage(pngOf(source), GrayImageQuality.high)!;
      // 128 は階調1（85）と2（170）の間 → ディザで両者が混在する
      expect(gray.pixels.every((p) => p == 1 || p == 2), true);
      expect(gray.pixels.any((p) => p == 1), true);
      expect(gray.pixels.any((p) => p == 2), true);
    });

    test('縦長画像は高さが長辺になる', () {
      final source = img.Image(width: 30, height: 60);
      img.fill(source, color: img.ColorRgb8(0, 0, 0));

      final gray = convertToGrayImage(pngOf(source), GrayImageQuality.low)!;
      expect(gray.height, GrayImageQuality.low.longSide);
      expect(gray.width, 12);
    });

    test('画像でないデータは null', () {
      expect(
        convertToGrayImage(Uint8List.fromList([1, 2, 3]), GrayImageQuality.low),
        isNull,
      );
    });
  });
}
