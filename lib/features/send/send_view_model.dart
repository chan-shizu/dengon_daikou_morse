import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/morse/morse_encoder.dart';

part 'send_view_model.g.dart';

class SendState {
  const SendState({
    this.inputText = '',
    this.morseSequence = const [],
    this.isSending = false,
    this.unitMs = 200,
  });

  final String inputText;
  final List<String?> morseSequence;
  final bool isSending;
  final int unitMs;

  SendState copyWith({
    String? inputText,
    List<String?>? morseSequence,
    bool? isSending,
    int? unitMs,
  }) {
    return SendState(
      inputText: inputText ?? this.inputText,
      morseSequence: morseSequence ?? this.morseSequence,
      isSending: isSending ?? this.isSending,
      unitMs: unitMs ?? this.unitMs,
    );
  }
}

@riverpod
class SendViewModel extends _$SendViewModel {
  bool _cancelled = false;

  @override
  SendState build() => const SendState();

  void updateInput(String text) {
    state = state.copyWith(
      inputText: text,
      morseSequence: MorseEncoder.encode(text),
    );
  }

  void setUnitMs(int ms) {
    state = state.copyWith(unitMs: ms);
  }

  Future<void> startSending() async {
    if (state.isSending || state.inputText.isEmpty) return;
    _cancelled = false;
    state = state.copyWith(isSending: true);

    try {
      await WakelockPlus.enable();
      await _flashMorse();
    } catch (_) {
      // シミュレータ等でライトが使えない場合は無視
    } finally {
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      state = state.copyWith(isSending: false);
    }
  }

  void stopSending() {
    _cancelled = true;
  }

  Future<void> _flashMorse() async {
    final text = state.inputText;
    final sequence = state.morseSequence;
    final unitMs = state.unitMs;
    final chars = text.split('');

    bool isFirst = true;
    bool prevWasSpace = false;

    for (int i = 0; i < chars.length; i++) {
      if (_cancelled) break;

      final ch = chars[i];

      if (ch == ' ' || ch == '　') {
        // 単語間: 7単位 OFF
        await _sleep(7 * unitMs);
        prevWasSpace = true;
        continue;
      }

      final code = sequence[i];
      if (code == null) continue;

      // 文字間: 3単位 OFF（最初の文字と単語直後はスキップ）
      if (!isFirst && !prevWasSpace) {
        await _sleep(3 * unitMs);
        if (_cancelled) break;
      }
      isFirst = false;
      prevWasSpace = false;

      for (int j = 0; j < code.length; j++) {
        if (_cancelled) break;

        final onMs = (code[j] == '.' ? 1 : 3) * unitMs;
        await TorchLight.enableTorch();
        await _sleep(onMs);
        await TorchLight.disableTorch();

        if (_cancelled) break;

        // 記号間: 1単位 OFF（最後の記号の後はスキップ）
        if (j < code.length - 1) {
          await _sleep(unitMs);
        }
      }
    }
  }

  // キャンセル対応のスリープ（50ms チャンク単位でチェック）
  Future<void> _sleep(int ms) async {
    const chunk = 50;
    var remaining = ms;
    while (remaining > 0 && !_cancelled) {
      final wait = remaining.clamp(0, chunk);
      await Future.delayed(Duration(milliseconds: wait));
      remaining -= chunk;
    }
  }
}
