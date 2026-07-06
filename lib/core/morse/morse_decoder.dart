import '../constants.dart';
import 'morse_encoder.dart';
import 'morse_protocol.dart';
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

/// 受信の進行フェーズ（通信プロトコルの状態機械）
enum ReceivePhase {
  /// 開始合図（プリアンブル）待ち
  waitingSignal,

  /// 言語符号待ち
  waitingLanguage,

  /// 本文受信中
  receivingBody,

  /// 終了符号を受信して完了
  done,
}

/// ON/OFF 継続時間列を通信プロトコルに沿ってテキストにデコードする。
///
/// プリアンブル → 言語符号 → 本文 → 終了符号 の順に解釈する。
/// 単位時間はプリアンブルの点の長さ（中央値）から自動校正するため、
/// 送信側とスライダーを合わせる必要はない。
///
/// 校正後のタイミング判定（単位時間 unitMs 基準）:
/// - ON: 2単位未満 → 点、それ以上 → 線
/// - OFF: 2単位未満 → 記号間、2〜5単位 → 文字確定、5単位以上 → 文字確定+スペース
class MorseDecoder {
  MorseDecoder({required this.onCharacter});

  /// 本文の文字が確定するたびに呼ばれる（スペース含む）
  final void Function(String char) onCharacter;

  ReceivePhase _phase = ReceivePhase.waitingSignal;
  MorseLanguage? _language;
  int _unitMs = kDefaultUnitMs;
  final List<int> _preambleOnMs = [];
  final StringBuffer _symbols = StringBuffer();
  // 先頭や連続のスペースを出さないためのフラグ
  bool _lastWasSpace = true;

  ReceivePhase get phase => _phase;

  /// ヘッダーの言語符号で確定した言語（確定前は null）
  MorseLanguage? get language => _language;

  /// プリアンブルから校正した単位時間（校正前はデフォルト値）
  int get unitMs => _unitMs;

  /// 確定前の符号バッファ（UI表示用）
  String get pendingSymbols => _symbols.toString();

  void onSignal(SignalEvent event) {
    switch (_phase) {
      case ReceivePhase.waitingSignal:
        _onPreambleSignal(event);
      case ReceivePhase.waitingLanguage:
      case ReceivePhase.receivingBody:
        _onCodeSignal(event);
      case ReceivePhase.done:
        break;
    }
  }

  /// プリアンブル検出。単位時間が未知なので相対比較で判定する:
  /// 同じ長さの ON が [kPreambleMinDots] 個以上続き、その2倍以上の OFF で
  /// 終端したらプリアンブルとみなし、ON の中央値を単位時間とする。
  void _onPreambleSignal(SignalEvent event) {
    if (!event.isOn) {
      // ON が終わった: 点候補として記録。長さが揃わなければやり直し
      final d = event.durationMs;
      if (_preambleOnMs.isNotEmpty) {
        final unit = _median(_preambleOnMs);
        if (d > unit * 2 || d * 2 < unit) {
          _preambleOnMs.clear();
        }
      }
      _preambleOnMs.add(d);
      return;
    }
    // OFF が終わった: 点間（1単位）より明確に長ければ点列の終端
    if (_preambleOnMs.isEmpty) return;
    if (event.durationMs >= _median(_preambleOnMs) * 2) {
      if (_preambleOnMs.length >= kPreambleMinDots) {
        _unitMs = _median(_preambleOnMs);
        _phase = ReceivePhase.waitingLanguage;
      }
      _preambleOnMs.clear();
    }
  }

  void _onCodeSignal(SignalEvent event) {
    if (event.isOn) {
      // OFF が終わった: 長さに応じて文字・単語の区切りを判定
      if (event.durationMs >= 5 * _unitMs) {
        _flushSymbols();
        if (_phase == ReceivePhase.receivingBody && !_lastWasSpace) {
          onCharacter(' ');
          _lastWasSpace = true;
        }
      } else if (event.durationMs >= 2 * _unitMs) {
        _flushSymbols();
      }
    } else {
      // ON が終わった: 点か線を確定
      _symbols.write(event.durationMs < 2 * _unitMs ? '.' : '-');
    }
  }

  /// バッファ中の符号を強制的に文字確定する（受信停止・無音タイムアウト時）
  void flush() => _flushSymbols();

  void _flushSymbols() {
    if (_symbols.isEmpty) return;
    final code = _symbols.toString();
    _symbols.clear();

    switch (_phase) {
      case ReceivePhase.waitingLanguage:
        // 言語符号以外はノイズとして読み捨てる
        for (final lang in MorseLanguage.values) {
          if (code == lang.startCode) {
            _language = lang;
            _phase = ReceivePhase.receivingBody;
            break;
          }
        }
      case ReceivePhase.receivingBody:
        final language = _language!;
        if (code == language.endCode) {
          _phase = ReceivePhase.done;
          return;
        }
        final table = switch (language) {
          MorseLanguage.japanese => kJapaneseMorseTableReverse,
          MorseLanguage.english => kEnglishMorseTableReverse,
        };
        onCharacter(table[code] ?? '?');
        _lastWasSpace = false;
      case ReceivePhase.waitingSignal:
      case ReceivePhase.done:
        break;
    }
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }
}
