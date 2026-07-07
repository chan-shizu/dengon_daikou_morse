import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/audio/tone_synth.dart';
import '../../core/constants.dart';
import '../../core/image/gray_image.dart';
import '../../core/morse/morse_encoder.dart';
import '../../core/morse/morse_image_codec.dart';
import '../../core/morse/signal_plan.dart';

part 'send_view_model.g.dart';

/// 送信手段。
/// 光は点滅（単位 50〜500ms）、音はトーン波形の一括再生（単位 10〜100ms）で
/// 高速。光+音は光のタイミングに合わせて音も鳴らす（人が聞く用）
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
    this.soundUnitMs = kSoundDefaultUnitMs,
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

  // 光送信の単位時間
  final int unitMs;

  // 音送信の単位時間（マイク受信は高分解能なので短くできる）
  final int soundUnitMs;

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

  /// 現在の送信手段で使う単位時間
  int get effectiveUnitMs => mode == SendMode.sound ? soundUnitMs : unitMs;

  /// 画像の想定送信時間（ms）。画像未選択なら null
  int? get estimatedImageMs => image == null
      ? null
      : MorseImageCodec.transmissionMs(imagePayload, effectiveUnitMs);

  bool get canSend => switch (content) {
        SendContent.text => inputText.isNotEmpty,
        SendContent.image => image != null,
      };

  SendState copyWith({
    String? inputText,
    List<String?>? morseSequence,
    bool? isSending,
    int? unitMs,
    int? soundUnitMs,
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
      soundUnitMs: soundUnitMs ?? this.soundUnitMs,
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

  // 光+音モードで resume/pause するループ再生プレイヤー
  AudioPlayer? _player;

  // 音モードで合成波形を一括再生するプレイヤー
  AudioPlayer? _dataPlayer;

  // 画質変更時に変換し直すため、選択画像の元データを保持する
  Uint8List? _sourceImageBytes;

  @override
  SendState build() {
    ref.onDispose(() {
      _player?.dispose();
      _dataPlayer?.dispose();
    });
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

  void setSoundUnitMs(int ms) {
    state = state.copyWith(soundUnitMs: ms);
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
      if (state.mode == SendMode.sound) {
        await _sendAsTone();
      } else {
        if (state.mode.usesSound) {
          await _preparePlayer();
        }
        await _sendWithLight();
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
        await _dataPlayer?.stop();
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

  List<SignalPulse> _buildPlan() => switch (state.content) {
        SendContent.text => buildTextPlan(
            state.inputText, state.morseSequence, state.language),
        SendContent.image => buildImagePlan(state.imagePayload),
      };

  /// 光（または光+音）でパルス計画を順に点滅させる
  Future<void> _sendWithLight() async {
    final plan = _buildPlan();
    final unitMs = state.unitMs;
    final mode = state.mode;

    for (final pulse in plan) {
      if (_cancelled) return;

      state = state.copyWith(
        sendingCharIndex: pulse.charIndex,
        sentBits: pulse.bitIndex != null ? pulse.bitIndex! + 1 : null,
      );

      await _signalOn(mode);
      await _sleep(pulse.onUnits * unitMs);
      await _signalOff(mode);

      if (_cancelled) return;
      await _sleep(pulse.gapUnits * unitMs);
    }
  }

  /// 音送信: 計画全体をトーン波形（WAV）に合成して一括再生する。
  /// resume/pause 方式と違いジッタがないため短い単位時間で送れる
  Future<void> _sendAsTone() async {
    final plan = _buildPlan();
    final unitMs = state.soundUnitMs;

    final wav = synthesizeToneWav(plan, unitMs: unitMs);
    final file = File(
        '${Directory.systemTemp.path}/dengon_daikou_morse_tone.wav');
    await file.writeAsBytes(wav, flush: true);

    final player = _dataPlayer ??= AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(DeviceFileSource(file.path));

    // 再生の経過時間から送信位置（ハイライト・進捗）を更新しながら待つ
    final cumulativeMs = <int>[];
    var totalMs = 0;
    for (final pulse in plan) {
      totalMs += (pulse.onUnits + pulse.gapUnits) * unitMs;
      cumulativeMs.add(totalMs);
    }

    final startedAt = DateTime.now();
    var index = 0;
    while (!_cancelled) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      if (elapsed >= totalMs) break;
      while (index < plan.length - 1 && cumulativeMs[index] <= elapsed) {
        index++;
      }
      final pulse = plan[index];
      state = state.copyWith(
        sendingCharIndex: pulse.charIndex,
        sentBits: pulse.bitIndex != null ? pulse.bitIndex! + 1 : null,
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await player.stop();
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
