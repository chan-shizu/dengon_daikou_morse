import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/core/audio/goertzel.dart';
import 'package:dengon_daikou_morse/core/audio/tone_synth.dart';
import 'package:dengon_daikou_morse/core/constants.dart';
import 'package:dengon_daikou_morse/core/image/gray_image.dart';
import 'package:dengon_daikou_morse/core/morse/morse_decoder.dart';
import 'package:dengon_daikou_morse/core/morse/morse_encoder.dart';
import 'package:dengon_daikou_morse/core/morse/morse_image_codec.dart';
import 'package:dengon_daikou_morse/core/morse/morse_protocol.dart';
import 'package:dengon_daikou_morse/core/morse/signal_plan.dart';

const _sampleRate = 22050;

Uint8List _pcm16Bytes(Int16List pcm) =>
    pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes);

Int16List _sineWave(int samples, {double amplitude = 0.8}) => Int16List(samples)
  ..setAll(0, [
    for (var i = 0; i < samples; i++)
      (sin(2 * pi * kToneHz * i / _sampleRate) * amplitude * 32767).round(),
  ]);

/// WAV バイト列を PCM 部分だけにして Goertzel → Detector → Decoder に流す
MorseDecoder _decodeWav(Uint8List wav, {void Function(String)? onCharacter}) {
  final decoder = MorseDecoder(onCharacter: onCharacter ?? (_) {});
  final detector = LightSignalDetector(onEvent: decoder.onSignal);
  final goertzel = GoertzelToneDetector(
    sampleRate: _sampleRate,
    toneHz: kToneHz,
    onWindow: detector.addSample,
  );
  goertzel.addPcm16(Uint8List.sublistView(wav, 44)); // 44 = WAVヘッダー
  decoder.flush();
  return decoder;
}

void main() {
  group('SignalPlan', () {
    test('テキスト計画はヘッダー・本文・終了符号を含む', () {
      final plan = buildTextPlan(
        'イ', MorseEncoder.encode('イ'), MorseLanguage.japanese);

      // プリアンブル8点 + ホレ6符号 + イ(.-)2符号 + ラタ5符号
      expect(plan.length, 8 + 6 + 2 + 5);
      // 本文のパルスだけ文字位置を持つ
      expect(plan.where((p) => p.charIndex == 0).length, 2);
      // 末尾に余分な OFF はない
      expect(plan.last.gapUnits, 0);
    });

    test('単語間スペースは直前のパルスの OFF を7単位に広げる', () {
      final plan = buildTextPlan(
        'イ イ', MorseEncoder.encode('イ イ'), MorseLanguage.japanese);
      expect(plan.where((p) => p.gapUnits == 7).length, 1);
    });

    test('画像計画はビット位置を持つ', () {
      const image = GrayImage(width: 2, height: 1, pixels: [0, 3]);
      final payload = MorseImageCodec.encode(image);
      final plan = buildImagePlan(payload);

      expect(plan.length, 8 + codeLength(kImageStartCode) + payload.length);
      expect(plan.last.bitIndex, payload.length - 1);
    });
  });

  group('GoertzelToneDetector', () {
    test('トーンは高い振幅、無音はほぼゼロになる', () {
      final magnitudes = <double>[];
      final goertzel = GoertzelToneDetector(
        sampleRate: _sampleRate,
        toneHz: kToneHz,
        onWindow: (m, _) => magnitudes.add(m),
      );

      goertzel.addPcm16(_pcm16Bytes(_sineWave(2205))); // 100ms のトーン
      goertzel.addPcm16(_pcm16Bytes(Int16List(2205))); // 100ms の無音

      final toneAvg = magnitudes.sublist(2, 18).reduce((a, b) => a + b) / 16;
      final silentAvg = magnitudes.sublist(22, 38).reduce((a, b) => a + b) / 16;
      expect(toneAvg, greaterThan(150));
      expect(silentAvg, lessThan(10));
    });

    test('タイムスタンプはサンプル数基準で進む', () {
      final times = <int>[];
      final goertzel = GoertzelToneDetector(
        sampleRate: _sampleRate,
        toneHz: kToneHz,
        onWindow: (_, t) => times.add(t),
      );
      goertzel.addPcm16(_pcm16Bytes(Int16List(_sampleRate))); // 1秒

      // 窓サイズ（110サンプル≒5ms）で刻むため端数分だけ手前になる
      expect(times.last, closeTo(1000, 10));
      expect(times.first, closeTo(5, 2));
    });
  });

  group('synthesizeToneWav', () {
    test('WAVサイズが計画の長さと一致する', () {
      final plan = [
        const SignalPulse(onUnits: 1, gapUnits: 1),
        const SignalPulse(onUnits: 3, gapUnits: 0),
      ];
      final wav = synthesizeToneWav(
        plan,
        unitMs: 20,
        sampleRate: _sampleRate,
        leadInMs: 100,
        leadOutMs: 100,
      );

      // 合計 100 + (1+1+3)*20 + 100 = 300ms
      final expectedSamples = 300 * _sampleRate ~/ 1000;
      expect(wav.length, 44 + expectedSamples * 2);
    });
  });

  group('音声エンドツーエンド', () {
    test('テキストを波形合成→トーン検出で復元できる', () {
      const text = 'モールス';
      final plan = buildTextPlan(
        text, MorseEncoder.encode(text), MorseLanguage.japanese);
      final wav = synthesizeToneWav(
        plan,
        unitMs: kSoundDefaultUnitMs,
        sampleRate: _sampleRate,
      );

      final buffer = StringBuffer();
      final decoder = _decodeWav(wav, onCharacter: buffer.write);

      expect(buffer.toString(), text);
      expect(decoder.phase, ReceivePhase.done);
      expect(decoder.unitMs, closeTo(kSoundDefaultUnitMs, 6));
    });

    test('画像を波形合成→トーン検出で復元できる', () {
      const image = GrayImage(
        width: 4,
        height: 2,
        pixels: [0, 1, 2, 3, 3, 2, 1, 0],
      );
      final wav = synthesizeToneWav(
        buildImagePlan(MorseImageCodec.encode(image)),
        unitMs: kSoundDefaultUnitMs,
        sampleRate: _sampleRate,
      );

      final decoder = _decodeWav(wav);
      expect(decoder.phase, ReceivePhase.done);
      expect(decoder.image!.pixels, image.pixels);
    });
  });
}

/// 符号の記号数（テストの期待値計算用）
int codeLength(String code) => code.length;
