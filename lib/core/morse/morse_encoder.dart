import 'morse_table.dart';

class MorseEncoder {
  // ひらがな → カタカナ変換（U+3041〜U+3096）
  static String _toKatakana(String text) {
    return text.replaceAllMapped(
      RegExp(r'[ぁ-ゖ]'),
      (m) => String.fromCharCode(m[0]!.codeUnitAt(0) + 0x60),
    );
  }

  /// テキストを各文字のモールス符号（'.' と '-' の文字列）リストに変換。
  /// 変換できない文字は null として返す。
  static List<String?> encode(String text) {
    final normalized = _toKatakana(text.toUpperCase());
    return normalized.split('').map((ch) => kMorseTable[ch]).toList();
  }
}
