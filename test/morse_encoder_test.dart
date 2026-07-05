import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/core/morse/morse_encoder.dart';

void main() {
  group('MorseEncoder', () {
    test('英語モードで英字を変換できる', () {
      expect(
        MorseEncoder.encode('A', language: MorseLanguage.english),
        ['.-'],
      );
      expect(
        MorseEncoder.encode('SOS', language: MorseLanguage.english),
        ['...', '---', '...'],
      );
    });

    test('日本語モードでは英字は変換できない', () {
      expect(MorseEncoder.encode('SOS'), [null, null, null]);
    });

    test('英語モードではカナは変換できない', () {
      expect(
        MorseEncoder.encode('アA', language: MorseLanguage.english),
        [null, '.-'],
      );
    });

    test('数字は両モードで変換できる', () {
      expect(MorseEncoder.encode('1'), ['.----']);
      expect(
        MorseEncoder.encode('1', language: MorseLanguage.english),
        ['.----'],
      );
    });

    test('カタカナを変換できる', () {
      // モ: -..-.  ー: .--.-  ル: -.---.  ス: ---.-
      expect(MorseEncoder.encode('モールス'), ['-..-.',  '.--.-', '-.---.', '---.-']);
    });

    test('ひらがなをカタカナとして変換できる', () {
      expect(MorseEncoder.encode('あ'), ['--.--']); // ア
      expect(MorseEncoder.encode('いろは'), ['.-', '.-.-', '-...']); // イ ロ ハ
    });

    test('変換できない文字は null を返す', () {
      final result = MorseEncoder.encode('ア！');
      expect(result[0], '--.--');
      expect(result[1], null);
    });

    test('重複する符号がないこと', () {
      const table = {
        'ア': '--.--', 'イ': '.-', 'ウ': '..-', 'エ': '-.---', 'オ': '.-...',
        'カ': '.-..', 'キ': '-.-..',
        'ロ': '.-.-', 'ン': '.-.-.',
        'ケ': '-.--', 'モ': '-..-.',
        'ル': '-.---.', 'リ': '--.',
      };
      final values = table.values.toList();
      final unique = values.toSet();
      expect(values.length, unique.length, reason: '重複する符号があります: $table');
    });
  });
}
