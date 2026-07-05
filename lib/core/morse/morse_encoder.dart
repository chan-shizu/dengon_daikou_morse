import 'morse_table.dart';

enum MorseLanguage {
  japanese('日本語'),
  english('英語');

  const MorseLanguage(this.label);

  final String label;

  /// この言語の入力欄で許可する文字（数字・記号・スペースは共通）
  RegExp get allowedChars => switch (this) {
        MorseLanguage.japanese => RegExp(r'[ぁ-ゖァ-ヶー゛゜0-9.,? 　]'),
        MorseLanguage.english => RegExp(r'[A-Za-z0-9.,? 　]'),
      };

  /// テキストからこの言語で入力できない文字を取り除く
  String filterText(String text) =>
      text.split('').where((ch) => allowedChars.hasMatch(ch)).join();
}

class MorseEncoder {
  // ひらがな → カタカナ変換（U+3041〜U+3096）
  static String _toKatakana(String text) {
    return text.replaceAllMapped(
      RegExp(r'[ぁ-ゖ]'),
      (m) => String.fromCharCode(m[0]!.codeUnitAt(0) + 0x60),
    );
  }

  /// テキストを各文字のモールス符号（'.' と '-' の文字列）リストに変換。
  /// 選択した言語の表にない文字は null として返す。
  static List<String?> encode(
    String text, {
    MorseLanguage language = MorseLanguage.japanese,
  }) {
    final table = switch (language) {
      MorseLanguage.japanese => kJapaneseMorseTable,
      MorseLanguage.english => kEnglishMorseTable,
    };
    var normalized = text.toUpperCase();
    if (language == MorseLanguage.japanese) {
      normalized = _toKatakana(normalized);
    }
    return normalized.split('').map((ch) => table[ch]).toList();
  }
}
