import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/morse/morse_encoder.dart';

part 'send_view_model.g.dart';

class SendState {
  const SendState({
    this.inputText = '',
    this.morseSequence = const [],
  });

  final String inputText;

  // 各文字のモールス符号（変換不能は null）
  final List<String?> morseSequence;
}

@riverpod
class SendViewModel extends _$SendViewModel {
  @override
  SendState build() => const SendState();

  void updateInput(String text) {
    state = SendState(
      inputText: text,
      morseSequence: MorseEncoder.encode(text),
    );
  }
}
