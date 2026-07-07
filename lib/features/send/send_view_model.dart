import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/constants.dart';
import '../../core/image/gray_image.dart';
import '../../core/morse/morse_encoder.dart';
import '../../core/morse/morse_image_codec.dart';
import '../../core/morse/morse_protocol.dart';

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

/// 送信する内容の種別
enum SendContent {
  text('テキスト'),
  image('画像');

  const SendContent(this.label);

  final String label;
}

class SendState {
  const SendState({
    this.inputText = '',
    this.morseSequence = const [],
    this.isSending = false,
    this.unitMs = kDefaultUnitMs,
    this.sendingCharIndex,
    this.mode = SendMode.light,
    this.language = MorseLanguage.japanese,
    this.content = SendContent.text,
    this.imageQuality = GrayImageQuality.medium,
    this.image,
    this.imagePayload = const [],
    this.sentBits = 0,
  });

  final String inputText;
  final List<String?> morseSequence;
  final bool isSending;
  final int unitMs;

  // 送信中の文字のインデックス（送信中以外は null）
  final int? sendingCharIndex;
  final SendMode mode;
  final MorseLanguage language;

  final SendContent content;
  final GrayImageQuality imageQuality;

  // 4階調変換済みの送信画像（未選択なら null）
  final GrayImage? image;

  // 画像の送信ビット列（メタ + 画素、反転適用済み）
  final List<bool> imagePayload;

  // 画像送信の進捗（送信済みビット数）
  final int sentBits;

  /// 画像の想定送信時間（ms）。画像未選択なら null
  int? get estimatedImageMs => image == null
      ? null
      : MorseImageCodec.transmissionMs(imagePayload, unitMs);

  bool get canSend => switch (content) {
        SendContent.text => inputText.isNotEmpty,
        SendContent.image => image != null,
      };

  SendState copyWith({
    String? inputText,
    List<String?>? morseSequence,
    bool? isSending,
    int? unitMs,
    int? sendingCharIndex,
    SendMode? mode,
    MorseLanguage? language,
    SendContent? content,
    GrayImageQuality? imageQuality,
    GrayImage? image,
    List<bool>? imagePayload,
    int? sentBits,
  }) {
    return SendState(
      inputText: inputText ?? this.inputText,
      morseSequence: morseSequence ?? this.morseSequence,
      isSending: isSending ?? this.isSending,
      unitMs: unitMs ?? this.unitMs,
      // 送信位置は毎回明示的に渡す（送信終了時に null へ戻すため）
      sendingCharIndex: sendingCharIndex,
      mode: mode ?? this.mode,
      language: language ?? this.language,
      content: content ?? this.content,
      imageQuality: imageQuality ?? this.imageQuality,
      image: image ?? this.image,
      imagePayload: imagePayload ?? this.imagePayload,
      sentBits: sentBits ?? this.sentBits,
    );
  }
}

@riverpod
class SendViewModel extends _$SendViewModel {
  bool _cancelled = false;
  AudioPlayer? _player;

  // 画質変更時に変換し直すため、選択画像の元データを保持する
  Uint8List? _sourceImageBytes;

  @override
  SendState build() {
    ref.onDispose(() => _player?.dispose());
    return const SendState();
  }

  void updateInput(String text) {
    state = state.copyWith(
      inputText: text,
      morseSequence: MorseEncoder.encode(text, language: state.language),
    );
  }

  void setUnitMs(int ms) {
    state = state.copyWith(unitMs: ms);
  }

  void setMode(SendMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setLanguage(MorseLanguage language) {
    // 入力済みテキストから新しい言語で入力できない文字を除き、変換し直す
    final filtered = language.filterText(state.inputText);
    state = state.copyWith(
      language: language,
      inputText: filtered,
      morseSequence: MorseEncoder.encode(filtered, language: language),
    );
  }

  void setContent(SendContent content) {
    state = state.copyWith(content: content);
  }

  /// 画像フォルダまたはカメラから画像を選び、4階調グレースケール化する
  Future<void> pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // 階調変換前の中間サイズ。これ以上の解像度は不要
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final image = convertToGrayImage(bytes, state.imageQuality);
    if (image == null) return;

    _sourceImageBytes = bytes;
    state = state.copyWith(
      image: image,
      imagePayload: MorseImageCodec.encode(image),
    );
  }

  void setImageQuality(GrayImageQuality quality) {
    // 選択済みの元画像があれば新しい画質で変換し直す
    final bytes = _sourceImageBytes;
    final image = bytes == null ? null : convertToGrayImage(bytes, quality);
    state = state.copyWith(
      imageQuality: quality,
      image: image,
      imagePayload: image == null ? null : MorseImageCodec.encode(image),
    );
  }

  Future<void> startSending() async {
    if (state.isSending || !state.canSend) return;
    _cancelled = false;
    state = state.copyWith(isSending: true, sentBits: 0);

    try {
      await WakelockPlus.enable();
      if (state.mode.usesSound) {
        await _preparePlayer();
      }
      switch (state.content) {
        case SendContent.text:
          await _sendMorse();
        case SendContent.image:
          await _sendImage();
      }
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
    final language = state.language;
    final chars = text.split('');

    // ヘッダー: 開始合図（プリアンブル）+ 言語符号
    await _sendCode(kPreambleCode, mode, unitMs);
    await _sleep(3 * unitMs);
    await _sendCode(language.startCode, mode, unitMs);

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

      // 文字間: 3単位 OFF（単語直後はスキップ）
      if (!prevWasSpace) {
        await _sleep(3 * unitMs);
        if (_cancelled) break;
      }
      prevWasSpace = false;

      state = state.copyWith(sendingCharIndex: i);
      await _sendCode(code, mode, unitMs);
    }

    // フッター: 終了符号
    if (_cancelled) return;
    state = state.copyWith(sendingCharIndex: null);
    await _sleep(3 * unitMs);
    await _sendCode(language.endCode, mode, unitMs);
  }

  /// 画像送信: プリアンブル → 画像モード符号 → メタ+画素ビット列。
  /// ビットは 0=点（1単位ON）/ 1=線（3単位ON）、ビット間は1単位OFF。
  /// 受信側は画素数に達した時点で完了するため終了符号はない
  Future<void> _sendImage() async {
    final payload = state.imagePayload;
    final unitMs = state.unitMs;
    final mode = state.mode;

    await _sendCode(kPreambleCode, mode, unitMs);
    await _sleep(3 * unitMs);
    await _sendCode(kImageStartCode, mode, unitMs);
    await _sleep(3 * unitMs);

    for (var i = 0; i < payload.length; i++) {
      if (_cancelled) return;

      await _signalOn(mode);
      await _sleep((payload[i] ? 3 : 1) * unitMs);
      await _signalOff(mode);

      state = state.copyWith(sentBits: i + 1);

      if (i < payload.length - 1) {
        await _sleep(unitMs);
      }
    }
  }

  /// 符号1つ分（'.' と '-' の列）を記号間1単位 OFF で点滅させる
  Future<void> _sendCode(String code, SendMode mode, int unitMs) async {
    for (int j = 0; j < code.length; j++) {
      if (_cancelled) return;

      final onMs = (code[j] == '.' ? 1 : 3) * unitMs;
      await _signalOn(mode);
      await _sleep(onMs);
      await _signalOff(mode);

      if (_cancelled) return;

      // 記号間: 1単位 OFF（最後の記号の後はスキップ）
      if (j < code.length - 1) {
        await _sleep(unitMs);
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
