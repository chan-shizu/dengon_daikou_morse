import 'dart:math';
import 'dart:typed_data';

/// PCM16 ストリームから特定周波数（トーン）の振幅を窓ごとに算出する。
///
/// 出力は輝度と同じ 0〜255 スケールなので、そのまま
/// `LightSignalDetector.addSample` に流せる。タイムスタンプは
/// 累積サンプル数から求めるため、マイク取り込みのジッタの影響を受けない。
class GoertzelToneDetector {
  GoertzelToneDetector({
    required this.sampleRate,
    required this.toneHz,
    int windowMs = 5,
    required this.onWindow,
  }) : _windowSize = sampleRate * windowMs ~/ 1000 {
    final k = (_windowSize * toneHz / sampleRate).round();
    _coeff = 2 * cos(2 * pi * k / _windowSize);
  }

  final int sampleRate;
  final double toneHz;

  /// 窓ごとに (トーン振幅 0〜255, サンプル時刻 ms) で呼ばれる
  final void Function(double magnitude, int timestampMs) onWindow;

  final int _windowSize;
  late final double _coeff;
  final List<double> _window = [];
  int _totalSamples = 0;

  /// リトルエンディアン PCM16 のバイト列を追加する
  void addPcm16(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _window.add(data.getInt16(i, Endian.little) / 32768);
      if (_window.length >= _windowSize) {
        _flushWindow();
      }
    }
  }

  void _flushWindow() {
    var s1 = 0.0;
    var s2 = 0.0;
    for (final sample in _window) {
      final s0 = sample + _coeff * s1 - s2;
      s2 = s1;
      s1 = s0;
    }
    final power = s1 * s1 + s2 * s2 - _coeff * s1 * s2;
    // 窓内のトーン振幅（0〜1）→ 輝度スケール（0〜255）
    final amplitude = 2 * sqrt(max(power, 0)) / _windowSize;

    _totalSamples += _window.length;
    _window.clear();
    onWindow(
      (amplitude * 255).clamp(0, 255),
      _totalSamples * 1000 ~/ sampleRate,
    );
  }
}
