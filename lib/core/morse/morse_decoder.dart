import 'morse_table.dart';

/// ライトの ON/OFF 遷移イベント。
/// [isOn] は遷移後の状態、[durationMs] は遷移前の状態が続いた時間。
class SignalEvent {
  const SignalEvent({required this.isOn, required this.durationMs});

  final bool isOn;
  final int durationMs;
}

/// 輝度サンプル列を ON/OFF イベントに変換する適応閾値検出器。
///
/// 直近ウィンドウの輝度 min/max の中間値を閾値とし、
/// ヒステリシスでチャタリングを防ぐ。コントラストが小さい間は
/// 点滅なしとみなしてイベントを出さない。
class LightSignalDetector {
  LightSignalDetector({
    required this.onEvent,
    this.windowMs = 2000,
    this.minContrast = 20.0,
  });

  final void Function(SignalEvent event) onEvent;

  /// 閾値算出に使うサンプルの保持期間
  final int windowMs;

  /// 点滅ありと判定する最小コントラスト（輝度 0〜255 スケール）
  final double minContrast;

  final List<({double luminance, int timestampMs})> _samples = [];
  bool? _isOn;
  int _stateStartMs = 0;

  /// 現在 ON と判定されているか（UIインジケータ用）
  bool get isOn => _isOn ?? false;

  void addSample(double luminance, int timestampMs) {
    _samples.add((luminance: luminance, timestampMs: timestampMs));
    _samples.removeWhere((s) => timestampMs - s.timestampMs > windowMs);

    var min = double.infinity;
    var max = double.negativeInfinity;
    for (final s in _samples) {
      if (s.luminance < min) min = s.luminance;
      if (s.luminance > max) max = s.luminance;
    }

    if (max - min < minContrast) {
      // 点滅なし。状態を未確定に戻す
      _isOn = null;
      return;
    }

    final mid = (min + max) / 2;
    final range = max - min;
    final onThreshold = mid + range * 0.1;
    final offThreshold = mid - range * 0.1;

    final bool next;
    if (_isOn == null) {
      next = luminance > mid;
    } else if (_isOn!) {
      next = luminance >= offThreshold;
    } else {
      next = luminance > onThreshold;
    }

    if (_isOn == null) {
      _isOn = next;
      _stateStartMs = timestampMs;
      return;
    }

    if (next != _isOn) {
      onEvent(SignalEvent(isOn: next, durationMs: timestampMs - _stateStartMs));
      _isOn = next;
      _stateStartMs = timestampMs;
    }
  }

  /// 現在の状態が続いている時間（無音タイムアウト判定用）
  int elapsedMs(int nowMs) => _isOn == null ? 0 : nowMs - _stateStartMs;

  void reset() {
    _samples.clear();
    _isOn = null;
  }
}

/// ON/OFF 継続時間列をモールス符号経由でテキストにデコードする。
///
/// タイミング判定（単位時間 unitMs 基準）:
/// - ON: 2単位未満 → 点、それ以上 → 線
/// - OFF: 2単位未満 → 記号間、2〜5単位 → 文字確定、5単位以上 → 文字確定+スペース
class MorseDecoder {
  MorseDecoder({
    required this.unitMs,
    required this.onCharacter,
  });

  final int unitMs;

  /// 文字が確定するたびに呼ばれる（スペース含む）
  final void Function(String char) onCharacter;

  final StringBuffer _symbols = StringBuffer();
  // 先頭や連続のスペースを出さないためのフラグ
  bool _lastWasSpace = true;

  /// 確定前の符号バッファ（UI表示用）
  String get pendingSymbols => _symbols.toString();

  void onSignal(SignalEvent event) {
    if (event.isOn) {
      // OFF が終わった: 長さに応じて文字・単語の区切りを判定
      if (event.durationMs >= 5 * unitMs) {
        _flushSymbols();
        if (!_lastWasSpace) {
          onCharacter(' ');
          _lastWasSpace = true;
        }
      } else if (event.durationMs >= 2 * unitMs) {
        _flushSymbols();
      }
    } else {
      // ON が終わった: 点か線を確定
      _symbols.write(event.durationMs < 2 * unitMs ? '.' : '-');
    }
  }

  /// バッファ中の符号を強制的に文字確定する（受信停止・無音タイムアウト時）
  void flush() => _flushSymbols();

  void _flushSymbols() {
    if (_symbols.isEmpty) return;
    final code = _symbols.toString();
    _symbols.clear();
    onCharacter(kMorseTableReverse[code] ?? '?');
    _lastWasSpace = false;
  }
}
