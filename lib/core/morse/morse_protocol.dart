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

/// 画像モード符号（言語符号の代わりに送る）: セクション区切り BT
/// この後にメタデータ [kImageMetaBits] ビット → 画素ビット列が続く
const String kImageStartCode = '-...-';

/// 画像メタデータの幅・高さそれぞれのビット数（最大255px）
const int kImageDimensionBits = 8;

/// 画像メタデータの総ビット数（幅 + 高さ + 反転フラグ）
const int kImageMetaBits = kImageDimensionBits * 2 + 1;

/// 符号1つの送信に要する単位数（点=ON1+OFF1、線=ON3+OFF1。末尾の OFF も含む）
int codeUnits(String code) =>
    code.split('').fold(0, (sum, s) => sum + (s == '.' ? 2 : 4));

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
