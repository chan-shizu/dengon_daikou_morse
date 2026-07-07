import 'dart:math';
import 'dart:typed_data';

import '../constants.dart';
import '../morse/signal_plan.dart';

/// 送信計画をトーン（正弦波）の WAV バイト列（PCM16 mono）に合成する。
///
/// resume/pause の切り替えではミリ秒単位のジッタが出るため、
/// タイミングを波形そのものに焼き込んで一括再生する。
/// 再生開始の取りこぼしを防ぐため先頭に [leadInMs] の無音を置き、
/// 末尾にも受信側が最後の符号を確定できるだけの無音を付ける。
Uint8List synthesizeToneWav(
  List<SignalPulse> plan, {
  required int unitMs,
  int sampleRate = 22050,
  double toneHz = kToneHz,
  double amplitude = 0.8,
  int leadInMs = 300,
  int leadOutMs = 300,
}) {
  int samplesOfMs(int ms) => ms * sampleRate ~/ 1000;
  int samplesOfUnits(int units) => samplesOfMs(units * unitMs);

  final totalSamples = samplesOfMs(leadInMs) +
      samplesOfMs(leadOutMs) +
      plan.fold<int>(
          0, (sum, p) => sum + samplesOfUnits(p.onUnits + p.gapUnits));

  final pcm = Int16List(totalSamples);
  // クリックノイズ防止の立ち上がり/立ち下がりランプ（2ms）
  final rampSamples = samplesOfMs(2);

  var pos = samplesOfMs(leadInMs);
  for (final pulse in plan) {
    final onSamples = samplesOfUnits(pulse.onUnits);
    for (var i = 0; i < onSamples; i++) {
      var a = amplitude;
      if (i < rampSamples) a *= i / rampSamples;
      final remaining = onSamples - 1 - i;
      if (remaining < rampSamples) a *= remaining / rampSamples;
      pcm[pos + i] = (sin(2 * pi * toneHz * i / sampleRate) * a * 32767).round();
    }
    pos += onSamples + samplesOfUnits(pulse.gapUnits);
  }
  return wavFromPcm16(pcm, sampleRate);
}

/// PCM16 mono を 44 バイトヘッダー付きの WAV に包む
Uint8List wavFromPcm16(Int16List pcm, int sampleRate) {
  final dataSize = pcm.length * 2;
  final bytes = ByteData(44 + dataSize);

  void writeAscii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt チャンクサイズ
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // バイトレート
  bytes.setUint16(32, 2, Endian.little); // ブロックアライン
  bytes.setUint16(34, 16, Endian.little); // ビット深度
  writeAscii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < pcm.length; i++) {
    bytes.setInt16(44 + i * 2, pcm[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}
