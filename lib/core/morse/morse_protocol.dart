import 'morse_encoder.dart';

// 同アプリ間通信のプロトコル符号。
// 送信は [プリアンブル] → [言語符号] → [本文] → [終了符号] の順に点滅する。
// 言語符号・終了符号は文字表の符号と衝突し得るため（例: CT はサ、AR はン）、
// 受信側は状態機械で「今どの位置か」に応じて解釈する。

/// 開始合図（点の連打）。
/// 受信側はこれで適応閾値を安定させ、点の長さから単位時間を校正する。
const String kPreambleCode = '........';

/// プリアンブルとして認める最小の点数（取りこぼしを許容）
const int kPreambleMinDots = 5;

extension MorseLanguageProtocol on MorseLanguage {
  /// 言語符号（開始合図の直後に送る）: 和文「ホレ」/ 欧文は送信開始 CT
  String get startCode => switch (this) {
        MorseLanguage.japanese => '-..---',
        MorseLanguage.english => '-.-.-',
      };

  /// 終了符号: 和文「ラタ」/ 欧文 AR
  String get endCode => switch (this) {
        MorseLanguage.japanese => '...-.',
        MorseLanguage.english => '.-.-.',
      };
}
