import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/image/gray_image.dart';
import '../../core/morse/morse_decoder.dart';
import '../../core/morse/morse_encoder.dart';

part 'receive_view_model.g.dart';

class ReceiveState {
  const ReceiveState({
    this.isReceiving = false,
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

  final bool isLightDetected;
  final String? errorMessage;

  ReceiveState copyWith({
    bool? isReceiving,
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
  LightSignalDetector? _detector;
  MorseDecoder? _decoder;
  int _lastEventMs = 0;
  int _lastPixelCount = 0;

  /// View がプレビュー表示に使う（受信中のみ非 null）
  CameraController? get cameraController => _controller;

  @override
  ReceiveState build() {
    ref.onDispose(_disposeCamera);
    return const ReceiveState();
  }

  Future<void> startReceiving() async {
    if (state.isReceiving) return;

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

      _controller = controller;
      await controller.startImageStream(_processFrame);
      // 長時間の画像受信中にスリープしないようにする
      try {
        await WakelockPlus.enable();
      } catch (_) {}
      // フェーズ・言語・画像・検出単位時間を初期状態に戻して受信開始
      state = ReceiveState(isReceiving: true, decodedText: state.decodedText);
    } on CameraException catch (e) {
      await _disposeCamera();
      state = state.copyWith(
        errorMessage: 'カメラを起動できませんでした: ${e.description ?? e.code}',
      );
    }
  }

  Future<void> stopReceiving() async {
    if (!state.isReceiving) return;
    await _disposeCamera();
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
    final decoder = _decoder;
    if (detector == null || decoder == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    detector.addSample(_centerLuminance(image), nowMs);

    // 送信終了後は OFF→ON 遷移が来ないため、無音が続いたら最後の文字を確定
    // （終了符号もここで確定して done になる）
    if (decoder.pendingSymbols.isNotEmpty &&
        !detector.isOn &&
        _lastEventMs > 0 &&
        nowMs - _lastEventMs >= 7 * decoder.unitMs) {
      decoder.flush();
    }

    if (decoder.phase == ReceivePhase.done) {
      // 受信完了: カメラを止める（ストリームのコールバック内なので次フレームで）
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

  Future<void> _disposeCamera() async {
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
    _detector = null;
  }
}
