import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/core/morse/morse_encoder.dart';

void main() {
  group('MorseEncoder', () {
    test('英字を変換できる', () {
      expect(MorseEncoder.encode('A'), ['.-']);
      expect(MorseEncoder.encode('SOS'), ['...', '---', '...']);
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
      final result = MorseEncoder.encode('A！');
      expect(result[0], '.-');
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
