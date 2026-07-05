import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/constants.dart';
import '../../core/morse/morse_encoder.dart';

part 'send_view_model.g.dart';

enum SendMode {
  light('光'),
  sound('音'),
  both('光+音');

  const SendMode(this.label);

  final String label;

  bool get usesLight => this != SendMode.sound;
  bool get usesSound => this != SendMode.light;
}

class SendState {
  const SendState({
    this.inputText = '',
    this.morseSequence = const [],
    this.isSending = false,
    this.unitMs = kDefaultUnitMs,
    this.sendingCharIndex,
    this.mode = SendMode.light,
  });

  final String inputText;
  final List<String?> morseSequence;
  final bool isSending;
  final int unitMs;

  // 送信中の文字のインデックス（送信中以外は null）
  final int? sendingCharIndex;
  final SendMode mode;

  SendState copyWith({
    String? inputText,
    List<String?>? morseSequence,
    bool? isSending,
    int? unitMs,
    int? sendingCharIndex,
    SendMode? mode,
  }) {
    return SendState(
      inputText: inputText ?? this.inputText,
      morseSequence: morseSequence ?? this.morseSequence,
      isSending: isSending ?? this.isSending,
      unitMs: unitMs ?? this.unitMs,
      // 送信位置は毎回明示的に渡す（送信終了時に null へ戻すため）
      sendingCharIndex: sendingCharIndex,
      mode: mode ?? this.mode,
    );
  }
}

@riverpod
class SendViewModel extends _$SendViewModel {
  bool _cancelled = false;
  AudioPlayer? _player;

  @override
  SendState build() {
    ref.onDispose(() => _player?.dispose());
    return const SendState();
  }

  void updateInput(String text) {
    state = state.copyWith(
      inputText: text,
      morseSequence: MorseEncoder.encode(text),
    );
  }

  void setUnitMs(int ms) {
    state = state.copyWith(unitMs: ms);
  }

  void setMode(SendMode mode) {
    state = state.copyWith(mode: mode);
  }

  Future<void> startSending() async {
    if (state.isSending || state.inputText.isEmpty) return;
    _cancelled = false;
    state = state.copyWith(isSending: true);

    try {
      await WakelockPlus.enable();
      if (state.mode.usesSound) {
        await _preparePlayer();
      }
      await _sendMorse();
    } catch (_) {
      // シミュレータ等でライトが使えない場合は無視
    } finally {
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
      try {
        await _player?.pause();
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

  // ループ再生するトーンを準備しておき、ON/OFF は resume/pause で切り替える
  Future<void> _preparePlayer() async {
    if (_player != null) return;
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setSource(AssetSource('sounds/tone.wav'));
    _player = player;
  }

  Future<void> _signalOn(SendMode mode) async {
    if (mode.usesLight) await TorchLight.enableTorch();
    if (mode.usesSound) await _player?.resume();
  }

  Future<void> _signalOff(SendMode mode) async {
    if (mode.usesLight) await TorchLight.disableTorch();
    if (mode.usesSound) await _player?.pause();
  }

  Future<void> _sendMorse() async {
    final text = state.inputText;
    final sequence = state.morseSequence;
    final unitMs = state.unitMs;
    final mode = state.mode;
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

      state = state.copyWith(sendingCharIndex: i);

      for (int j = 0; j < code.length; j++) {
        if (_cancelled) break;

        final onMs = (code[j] == '.' ? 1 : 3) * unitMs;
        await _signalOn(mode);
        await _sleep(onMs);
        await _signalOff(mode);

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
