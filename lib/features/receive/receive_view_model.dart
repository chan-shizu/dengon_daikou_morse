import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/audio/goertzel.dart';
import '../../core/constants.dart';
import '../../core/image/gray_image.dart';
import '../../core/morse/morse_decoder.dart';
import '../../core/morse/morse_encoder.dart';

part 'receive_view_model.g.dart';

/// 受信手段（光=カメラ / 音=マイク）
enum ReceiveSignal {
  light('光（カメラ）'),
  sound('音（マイク）');

  const ReceiveSignal(this.label);

  final String label;
}

class ReceiveState {
  const ReceiveState({
    this.isReceiving = false,
    this.signal = ReceiveSignal.light,
    this.decodedText = '',
    this.currentSymbols = '',
    this.phase = ReceivePhase.waitingSignal,
    this.language,
    this.image,
    this.detectedUnitMs,
    this.isLightDetected = false,
    this.errorMessage,
  });

  final bool isReceiving;
  final ReceiveSignal signal;
  final String decodedText;

  // 確定前のモールス符号バッファ
  final String currentSymbols;

  // プロトコルの進行フェーズ
  final ReceivePhase phase;

  // ヘッダーの言語符号で確定した言語（テキストモード以外は null）
  final MorseLanguage? language;

  // 受信中/受信済みの画像（画像モード以外は null）。受信途中は部分画像
  final GrayImage? image;

  // プリアンブルから自動検出した単位時間（検出前は null）
  final int? detectedUnitMs;

  // 光またはトーンを検出中か（インジケータ用）
  final bool isLightDetected;
  final String? errorMessage;

  ReceiveState copyWith({
    bool? isReceiving,
    ReceiveSignal? signal,
    String? decodedText,
    String? currentSymbols,
    ReceivePhase? phase,
    MorseLanguage? language,
    GrayImage? image,
    int? detectedUnitMs,
    bool? isLightDetected,
    String? errorMessage,
  }) {
    return ReceiveState(
      isReceiving: isReceiving ?? this.isReceiving,
      signal: signal ?? this.signal,
      decodedText: decodedText ?? this.decodedText,
      currentSymbols: currentSymbols ?? this.currentSymbols,
      phase: phase ?? this.phase,
      language: language ?? this.language,
      image: image ?? this.image,
      detectedUnitMs: detectedUnitMs ?? this.detectedUnitMs,
      isLightDetected: isLightDetected ?? this.isLightDetected,
      errorMessage: errorMessage,
    );
  }
}

@riverpod
class ReceiveViewModel extends _$ReceiveViewModel {
  CameraController? _controller;
  AudioRecorder? _recorder;
  StreamSubscription<Object?>? _audioSub;
  GoertzelToneDetector? _goertzel;
  LightSignalDetector? _detector;
  MorseDecoder? _decoder;
  int _lastEventMs = 0;
  int _lastPixelCount = 0;

  /// View がプレビュー表示に使う（光受信中のみ非 null）
  CameraController? get cameraController => _controller;

  @override
  ReceiveState build() {
    ref.onDispose(_disposeCapture);
    return const ReceiveState();
  }

  void setSignal(ReceiveSignal signal) {
    if (state.isReceiving) return;
    state = state.copyWith(signal: signal);
  }

  Future<void> startReceiving() async {
    if (state.isReceiving) return;

    _decoder = MorseDecoder(
      onCharacter: (char) {
        state = state.copyWith(decodedText: state.decodedText + char);
      },
    );
    _detector = LightSignalDetector(
      onEvent: (event) {
        _lastEventMs = DateTime.now().millisecondsSinceEpoch;
        _decoder!.onSignal(event);
      },
    );
    _lastEventMs = 0;
    _lastPixelCount = 0;

    final started = switch (state.signal) {
      ReceiveSignal.light => await _startCamera(),
      ReceiveSignal.sound => await _startMicrophone(),
    };
    if (!started) return;

    // 長時間受信中にスリープしないようにする
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    // フェーズ・言語・画像・検出単位時間を初期状態に戻して受信開始
    state = ReceiveState(
      isReceiving: true,
      signal: state.signal,
      decodedText: state.decodedText,
    );
  }

  Future<bool> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();

      // 自動露出・オートフォーカスが点滅検知に干渉するためロック
      try {
        await controller.setExposureMode(ExposureMode.locked);
        await controller.setFocusMode(FocusMode.locked);
      } catch (_) {
        // ロック非対応の端末では成り行きで動かす
      }

      _controller = controller;
      await controller.startImageStream(_processFrame);
      return true;
    } on CameraException catch (e) {
      await _disposeCapture();
      state = state.copyWith(
        errorMessage: 'カメラを起動できませんでした: ${e.description ?? e.code}',
      );
      return false;
    }
  }

  Future<bool> _startMicrophone() async {
    try {
      final recorder = AudioRecorder();
      if (!await recorder.hasPermission()) {
        recorder.dispose();
        state = state.copyWith(errorMessage: 'マイクの使用が許可されていません');
        return false;
      }

      _goertzel = GoertzelToneDetector(
        sampleRate: kAudioSampleRate,
        toneHz: kToneHz,
        onWindow: (magnitude, timestampMs) =>
            _detector?.addSample(magnitude, timestampMs),
      );

      final stream = await recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kAudioSampleRate,
        numChannels: 1,
      ));
      _recorder = recorder;
      _audioSub = stream.listen((chunk) {
        _goertzel?.addPcm16(chunk);
        _afterSamples();
      });
      return true;
    } catch (e) {
      await _disposeCapture();
      state = state.copyWith(errorMessage: 'マイクを起動できませんでした: $e');
      return false;
    }
  }

  Future<void> stopReceiving() async {
    if (!state.isReceiving) return;
    await _disposeCapture();
    _decoder?.flush();
    state = state.copyWith(
      isReceiving: false,
      isLightDetected: false,
      currentSymbols: '',
      phase: _decoder?.phase,
      image: _decoder?.image,
    );
  }

  void clearText() {
    state = state.copyWith(decodedText: '', currentSymbols: '');
  }

  void _processFrame(CameraImage image) {
    final detector = _detector;
    if (detector == null) return;

    detector.addSample(
      _centerLuminance(image),
      DateTime.now().millisecondsSinceEpoch,
    );
    _afterSamples();
  }

  /// サンプル追加後の共通処理: 無音タイムアウト・完了判定・状態同期
  void _afterSamples() {
    final detector = _detector;
    final decoder = _decoder;
    if (detector == null || decoder == null) return;

    // 送信終了後は OFF→ON 遷移が来ないため、無音が続いたら最後の文字を確定
    // （終了符号もここで確定して done になる）
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (decoder.pendingSymbols.isNotEmpty &&
        !detector.isOn &&
        _lastEventMs > 0 &&
        nowMs - _lastEventMs >= 7 * decoder.unitMs) {
      decoder.flush();
    }

    if (decoder.phase == ReceivePhase.done) {
      // 受信完了: 取り込みを止める（ストリームのコールバック内なので次周期で）
      unawaited(Future(stopReceiving));
    }

    if (detector.isOn != state.isLightDetected ||
        decoder.pendingSymbols != state.currentSymbols ||
        decoder.phase != state.phase ||
        decoder.receivedPixelCount != _lastPixelCount) {
      _lastPixelCount = decoder.receivedPixelCount;
      state = state.copyWith(
        isLightDetected: detector.isOn,
        currentSymbols: decoder.pendingSymbols,
        phase: decoder.phase,
        language: decoder.language,
        image: decoder.image,
        detectedUnitMs:
            decoder.phase == ReceivePhase.waitingSignal ? null : decoder.unitMs,
      );
    }
  }

  /// フレーム中央 1/3 領域の平均輝度（0〜255）。
  /// Android は YUV420 の Y プレーン、iOS は BGRA8888。
  double _centerLuminance(CameraImage image) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final width = image.width;
    final height = image.height;
    final rowStride = plane.bytesPerRow;
    // BGRA はピクセルあたり4バイト、YUV420 の Y プレーンは1バイト
    final pixelStride = Platform.isIOS ? 4 : (plane.bytesPerPixel ?? 1);
    // BGRA の輝度は G チャンネル（先頭から1バイト目）で代用
    final channelOffset = Platform.isIOS ? 1 : 0;

    final x0 = width ~/ 3;
    final x1 = width * 2 ~/ 3;
    final y0 = height ~/ 3;
    final y1 = height * 2 ~/ 3;

    var sum = 0;
    var count = 0;
    for (var y = y0; y < y1; y += 4) {
      final rowStart = y * rowStride;
      for (var x = x0; x < x1; x += 4) {
        final index = rowStart + x * pixelStride + channelOffset;
        if (index < bytes.length) {
          sum += bytes[index];
          count++;
        }
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  Future<void> _disposeCapture() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      await controller.dispose();
    }

    await _audioSub?.cancel();
    _audioSub = null;
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
      recorder.dispose();
    }
    _goertzel = null;
    _detector = null;
  }
}
