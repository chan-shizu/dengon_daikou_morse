import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/core/morse/morse_decoder.dart';
import 'package:dengon_daikou_morse/core/morse/morse_encoder.dart';
import 'package:dengon_daikou_morse/core/morse/morse_protocol.dart';

const _unitMs = 200;

/// 送信仕様どおりの SignalEvent 列を組み立てるビルダー
/// （点=1・線=3単位ON、記号間=1・文字間=3・単語間=7単位OFF）
class _EventBuilder {
  _EventBuilder({this.unitMs = _unitMs});

  final int unitMs;
  final List<SignalEvent> events = [];
  int _offMs = 100 * _unitMs; // 送信開始前の長い暗闇

  /// 直前の OFF を確定して onMs だけ点灯する
  void pulse(int onMs) {
    events.add(SignalEvent(isOn: true, durationMs: _offMs));
    events.add(SignalEvent(isOn: false, durationMs: onMs));
    _offMs = unitMs; // 既定は記号間ギャップ
  }

  /// 次の点灯までの OFF 時間を指定する
  void gap(int ms) => _offMs = ms;

  /// 符号1つ分を送り、文字間ギャップで終える
  void code(String code) {
    for (final symbol in code.split('')) {
      pulse((symbol == '.' ? 1 : 3) * unitMs);
    }
    gap(3 * unitMs);
  }

  /// プロトコルヘッダー（プリアンブル + 言語符号）
  void header(MorseLanguage language) {
    code(kPreambleCode);
    code(language.startCode);
  }
}

/// テキストをプロトコル込みの SignalEvent 列に変換する
List<SignalEvent> _encodeToEvents(
  String text, {
  int unitMs = _unitMs,
  MorseLanguage language = MorseLanguage.japanese,
}) {
  final builder = _EventBuilder(unitMs: unitMs);
  builder.header(language);

  final codes = MorseEncoder.encode(text, language: language);
  final chars = text.split('');
  for (var i = 0; i < chars.length; i++) {
    if (chars[i] == ' ') {
      builder.gap(7 * unitMs);
      continue;
    }
    final code = codes[i];
    if (code == null) continue;
    builder.code(code);
  }

  builder.code(language.endCode);
  return builder.events;
}

({String text, MorseDecoder decoder}) _decode(List<SignalEvent> events) {
  final buffer = StringBuffer();
  final decoder = MorseDecoder(onCharacter: buffer.write);
  events.forEach(decoder.onSignal);
  decoder.flush();
  return (text: buffer.toString(), decoder: decoder);
}

void main() {
  group('MorseDecoder（プロトコル）', () {
    test('和文をデコードして完了する', () {
      final result = _decode(_encodeToEvents('モールス'));
      expect(result.text, 'モールス');
      expect(result.decoder.language, MorseLanguage.japanese);
      expect(result.decoder.phase, ReceivePhase.done);
    });

    test('言語符号により欧文としてデコードされる', () {
      // 従来は逆引きが和文優先で SOS がラレラになっていた
      final result =
          _decode(_encodeToEvents('SOS', language: MorseLanguage.english));
      expect(result.text, 'SOS');
      expect(result.decoder.language, MorseLanguage.english);
      expect(result.decoder.phase, ReceivePhase.done);
    });

    test('単語間スペースを復元できる', () {
      expect(_decode(_encodeToEvents('アオ カキ')).text, 'アオ カキ');
    });

    test('開始合図がなければ本文をデコードしない', () {
      final builder = _EventBuilder();
      builder.code(MorseLanguage.japanese.startCode);
      for (final code in MorseEncoder.encode('モールス')) {
        builder.code(code!);
      }
      final result = _decode(builder.events);
      expect(result.text, '');
      expect(result.decoder.phase, ReceivePhase.waitingSignal);
    });

    test('プリアンブルから単位時間を自動校正できる', () {
      for (final unitMs in [80, 350]) {
        final result = _decode(_encodeToEvents('モールス', unitMs: unitMs));
        expect(result.text, 'モールス', reason: 'unitMs=$unitMs');
        expect(result.decoder.unitMs, unitMs);
      }
    });

    test('プリアンブル前のノイズ点滅を読み捨てる', () {
      final builder = _EventBuilder();
      // 不揃いな点滅（線と点の混在）の後に正規のヘッダー
      builder.pulse(3 * _unitMs);
      builder.pulse(_unitMs);
      builder.gap(5 * _unitMs);
      builder.header(MorseLanguage.japanese);
      builder.code('.-'); // イ
      builder.code(MorseLanguage.japanese.endCode);
      expect(_decode(builder.events).text, 'イ');
    });

    test('本文中の表にない符号は ? になる', () {
      final builder = _EventBuilder();
      builder.header(MorseLanguage.japanese);
      builder.code('......--'); // どの表にもない符号
      builder.code(MorseLanguage.japanese.endCode);
      expect(_decode(builder.events).text, '?');
    });

    test('終了符号の後の点滅は無視される', () {
      final builder = _EventBuilder();
      builder.header(MorseLanguage.japanese);
      builder.code('.-'); // イ
      builder.code(MorseLanguage.japanese.endCode);
      builder.code('-..'); // ホ（終了後なので無視されるべき）
      final result = _decode(builder.events);
      expect(result.text, 'イ');
      expect(result.decoder.phase, ReceivePhase.done);
    });

    test('タイミングの多少の揺れを許容する', () {
      // 点=0.8単位、線=2.5単位、文字間=2.6単位でも判定できる
      final builder = _EventBuilder();
      builder.header(MorseLanguage.japanese);
      // ト: ..-..
      builder.pulse((0.8 * _unitMs).round());
      builder.pulse(_unitMs);
      builder.gap((1.2 * _unitMs).round());
      builder.pulse((2.5 * _unitMs).round());
      builder.gap((0.7 * _unitMs).round());
      builder.pulse((0.9 * _unitMs).round());
      builder.pulse(_unitMs);
      builder.gap((2.6 * _unitMs).round());
      builder.code(MorseLanguage.japanese.endCode);
      expect(_decode(builder.events).text, 'ト');
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
      // プロトコル込みの点滅から輝度サンプル列を合成し、
      // Detector → Decoder のパイプライン全体を検証する
      const text = 'モールス';

      final buffer = StringBuffer();
      final decoder = MorseDecoder(onCharacter: buffer.write);
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

      void emitCode(String code) {
        for (var j = 0; j < code.length; j++) {
          if (j > 0) emit(false, _unitMs);
          emit(true, (code[j] == '.' ? 1 : 3) * _unitMs);
        }
      }

      emit(false, 1000); // 送信前の暗闇
      const language = MorseLanguage.japanese;
      emitCode(kPreambleCode);
      emit(false, 3 * _unitMs);
      emitCode(language.startCode);
      for (final code in MorseEncoder.encode(text)) {
        emit(false, 3 * _unitMs);
        emitCode(code!);
      }
      emit(false, 3 * _unitMs);
      emitCode(language.endCode);
      emit(false, 8 * _unitMs); // 送信後の暗闇
      decoder.flush();

      expect(buffer.toString(), text);
      expect(decoder.phase, ReceivePhase.done);
      expect(decoder.unitMs, closeTo(_unitMs, 40));
    });
  });
}
