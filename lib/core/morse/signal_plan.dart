import 'morse_encoder.dart';
import 'morse_protocol.dart';

/// 点灯（発音）1回分。[onUnits] 単位だけ ON し、続けて [gapUnits] 単位 OFF する。
class SignalPulse {
  const SignalPulse({
    required this.onUnits,
    required this.gapUnits,
    this.charIndex,
    this.bitIndex,
  });

  final int onUnits;
  final int gapUnits;

  /// テキスト送信でこのパルスが属する文字位置（ヘッダー・フッターは null）
  final int? charIndex;

  /// 画像送信でこのパルスが表すビット位置
  final int? bitIndex;

  SignalPulse withGap(int gapUnits) => SignalPulse(
        onUnits: onUnits,
        gapUnits: gapUnits,
        charIndex: charIndex,
        bitIndex: bitIndex,
      );
}

/// プロトコル全体の合計単位数（想定送信時間 = これ × unitMs）
int planUnits(List<SignalPulse> plan) =>
    plan.fold(0, (sum, p) => sum + p.onUnits + p.gapUnits);

/// テキスト送信の計画: プリアンブル → 言語符号 → 本文 → 終了符号。
/// 光・音どちらの送信でも同じ計画を使う。
List<SignalPulse> buildTextPlan(
  String text,
  List<String?> sequence,
  MorseLanguage language,
) {
  final pulses = <SignalPulse>[];
  _addCode(pulses, kPreambleCode);
  _addCode(pulses, language.startCode);

  final chars = text.split('');
  for (var i = 0; i < chars.length; i++) {
    if (chars[i] == ' ' || chars[i] == '　') {
      // 単語間: 直前のパルスの OFF を7単位に広げる
      pulses.add(pulses.removeLast().withGap(7));
      continue;
    }
    final code = sequence[i];
    if (code == null) continue;
    _addCode(pulses, code, charIndex: i);
  }

  _addCode(pulses, language.endCode);
  return _trimTrailingGap(pulses);
}

/// 画像送信の計画: プリアンブル → 画像モード符号 → メタ+画素ビット列。
/// 受信側は画素数に達した時点で完了するため終了符号はない。
List<SignalPulse> buildImagePlan(List<bool> payload) {
  final pulses = <SignalPulse>[];
  _addCode(pulses, kPreambleCode);
  _addCode(pulses, kImageStartCode);

  for (var i = 0; i < payload.length; i++) {
    pulses.add(SignalPulse(
      onUnits: payload[i] ? 3 : 1,
      gapUnits: 1,
      bitIndex: i,
    ));
  }
  return _trimTrailingGap(pulses);
}

/// 符号1つ分を追加する（記号間1単位、符号の後は文字間3単位 OFF）
void _addCode(List<SignalPulse> pulses, String code, {int? charIndex}) {
  for (var j = 0; j < code.length; j++) {
    pulses.add(SignalPulse(
      onUnits: code[j] == '.' ? 1 : 3,
      gapUnits: j < code.length - 1 ? 1 : 3,
      charIndex: charIndex,
    ));
  }
}

List<SignalPulse> _trimTrailingGap(List<SignalPulse> pulses) {
  if (pulses.isNotEmpty) {
    pulses.add(pulses.removeLast().withGap(0));
  }
  return pulses;
}
