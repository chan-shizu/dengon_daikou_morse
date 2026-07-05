import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/core/morse/morse_decoder.dart';
import 'package:dengon_daikou_morse/core/morse/morse_encoder.dart';

const _unitMs = 200;

/// テキストを送信仕様どおりの SignalEvent 列に変換する
/// （点=1・線=3単位ON、記号間=1・文字間=3・単語間=7単位OFF）
List<SignalEvent> _encodeToEvents(
  String text, {
  int unitMs = _unitMs,
  MorseLanguage language = MorseLanguage.japanese,
}) {
  final events = <SignalEvent>[];
  final codes = MorseEncoder.encode(text, language: language);
  final chars = text.split('');

  var offMs = unitMs * 100; // 送信開始前の長い暗闇
  for (var i = 0; i < chars.length; i++) {
    if (chars[i] == ' ') {
      offMs += 7 * unitMs;
      continue;
    }
    final code = codes[i];
    if (code == null) continue;
    if (offMs == 0) offMs = 3 * unitMs; // 文字間

    for (var j = 0; j < code.length; j++) {
      // OFF → ON 遷移（直前の OFF の長さを持つ）
      events.add(SignalEvent(isOn: true, durationMs: offMs));
      // ON → OFF 遷移
      final onMs = (code[j] == '.' ? 1 : 3) * unitMs;
      events.add(SignalEvent(isOn: false, durationMs: onMs));
      offMs = j < code.length - 1 ? unitMs : 0;
    }
  }
  return events;
}

String _decode(List<SignalEvent> events, {int unitMs = _unitMs}) {
  final buffer = StringBuffer();
  final decoder = MorseDecoder(unitMs: unitMs, onCharacter: buffer.write);
  events.forEach(decoder.onSignal);
  decoder.flush();
  return buffer.toString();
}

void main() {
  group('MorseDecoder', () {
    test('カタカナをデコードできる', () {
      expect(_decode(_encodeToEvents('モールス')), 'モールス');
    });

    test('英文と共通の符号は和文（カタカナ）として復元される', () {
      // S(...)=ラ、O(---)=レ。逆引きは和文優先
      expect(
        _decode(_encodeToEvents('SOS', language: MorseLanguage.english)),
        'ラレラ',
      );
    });

    test('単語間スペースを復元できる', () {
      expect(_decode(_encodeToEvents('アオ カキ')), 'アオ カキ');
    });

    test('送信開始前の長い暗闇で先頭にスペースが付かない', () {
      expect(_decode(_encodeToEvents('ア')), 'ア');
    });

    test('未知の符号は ? になる', () {
      // ........（8点）は表にない
      final events = <SignalEvent>[
        for (var i = 0; i < 8; i++) ...[
          SignalEvent(isOn: true, durationMs: i == 0 ? 10000 : _unitMs),
          const SignalEvent(isOn: false, durationMs: _unitMs),
        ],
      ];
      expect(_decode(events), '?');
    });

    test('タイミングの多少の揺れを許容する', () {
      // 点=0.8単位、線=2.5単位、文字間=2.6単位でも判定できる
      final events = <SignalEvent>[
        // ト: ..-..
        SignalEvent(isOn: true, durationMs: 10000),
        SignalEvent(isOn: false, durationMs: (0.8 * _unitMs).round()),
        SignalEvent(isOn: true, durationMs: _unitMs),
        SignalEvent(isOn: false, durationMs: (1.2 * _unitMs).round()),
        SignalEvent(isOn: true, durationMs: _unitMs),
        SignalEvent(isOn: false, durationMs: (2.5 * _unitMs).round()),
        SignalEvent(isOn: true, durationMs: (0.9 * _unitMs).round()),
        SignalEvent(isOn: false, durationMs: _unitMs),
        SignalEvent(isOn: true, durationMs: _unitMs),
        SignalEvent(isOn: false, durationMs: (0.7 * _unitMs).round()),
      ];
      expect(_decode(events), 'ト');
    });
  });

  group('LightSignalDetector', () {
    test('明暗の遷移で ON/OFF イベントが出る', () {
      final events = <SignalEvent>[];
      final detector = LightSignalDetector(onEvent: events.add);

      // 暗 500ms → 明 200ms → 暗 200ms（10ms 間隔サンプル）
      var t = 0;
      for (; t < 500; t += 10) {
        detector.addSample(10, t);
      }
      for (; t < 700; t += 10) {
        detector.addSample(200, t);
      }
      for (; t < 900; t += 10) {
        detector.addSample(10, t);
      }

      // 初回の状態確定（暗→明）ではイベントは出ず、以降の遷移のみ通知される
      expect(events.length, 1);
      expect(events[0].isOn, false);
      expect(events[0].durationMs, closeTo(200, 20));
    });

    test('低コントラストでは反応しない', () {
      final events = <SignalEvent>[];
      final detector = LightSignalDetector(onEvent: events.add);

      // 輝度変動が ±5 程度のノイズのみ
      for (var t = 0; t < 2000; t += 10) {
        detector.addSample(100 + (t % 20 == 0 ? 5 : -5), t);
      }

      expect(events, isEmpty);
      expect(detector.isOn, false);
    });

    test('連続した点滅を正しくイベント化できる', () {
      final events = <SignalEvent>[];
      final detector = LightSignalDetector(onEvent: events.add);

      // 暗 400ms → (明 200ms → 暗 200ms) x 3
      var t = 0;
      for (; t < 400; t += 10) {
        detector.addSample(10, t);
      }
      for (var i = 0; i < 3; i++) {
        final onEnd = t + 200;
        for (; t < onEnd; t += 10) {
          detector.addSample(200, t);
        }
        final offEnd = t + 200;
        for (; t < offEnd; t += 10) {
          detector.addSample(10, t);
        }
      }

      // 初回の暗→明はイベントなし。以降の5遷移が通知される
      expect(events.length, 5);
      expect(events.map((e) => e.isOn).toList(), [
        false, true, false, true, false, //
      ]);
    });
  });

  group('エンコード→デコード ラウンドトリップ', () {
    test('輝度サンプル経由でも復元できる', () {
      // エンコーダー出力から輝度サンプル列を合成し、
      // Detector → Decoder のパイプライン全体を検証する
      const text = 'モールス';
      final codes = MorseEncoder.encode(text);

      final buffer = StringBuffer();
      final decoder = MorseDecoder(unitMs: _unitMs, onCharacter: buffer.write);
      final detector = LightSignalDetector(
        onEvent: decoder.onSignal,
      );

      var t = 0;
      void emit(bool on, int durationMs) {
        final end = t + durationMs;
        for (; t < end; t += 33) {
          detector.addSample(on ? 220 : 15, t);
        }
      }

      emit(false, 1000); // 送信前の暗闇
      var first = true;
      for (final code in codes) {
        if (!first) emit(false, 3 * _unitMs);
        first = false;
        for (var j = 0; j < code!.length; j++) {
          if (j > 0) emit(false, _unitMs);
          emit(true, (code[j] == '.' ? 1 : 3) * _unitMs);
        }
      }
      emit(false, 8 * _unitMs); // 送信後の暗闇
      decoder.flush();

      expect(buffer.toString(), text);
    });
  });
}
