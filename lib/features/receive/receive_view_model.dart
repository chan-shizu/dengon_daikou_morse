import 'dart:io';

import 'package:camera/camera.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants.dart';
import '../../core/morse/morse_decoder.dart';

part 'receive_view_model.g.dart';

class ReceiveState {
  const ReceiveState({
    this.isReceiving = false,
    this.decodedText = '',
    this.currentSymbols = '',
    this.unitMs = kDefaultUnitMs,
    this.isLightDetected = false,
    this.errorMessage,
  });

  final bool isReceiving;
  final String decodedText;

  // 確定前のモールス符号バッファ
  final String currentSymbols;
  final int unitMs;
  final bool isLightDetected;
  final String? errorMessage;

  ReceiveState copyWith({
    bool? isReceiving,
    String? decodedText,
    String? currentSymbols,
    int? unitMs,
    bool? isLightDetected,
    String? errorMessage,
  }) {
    return ReceiveState(
      isReceiving: isReceiving ?? this.isReceiving,
      decodedText: decodedText ?? this.decodedText,
      currentSymbols: currentSymbols ?? this.currentSymbols,
      unitMs: unitMs ?? this.unitMs,
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
        unitMs: state.unitMs,
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

      _controller = controller;
      await controller.startImageStream(_processFrame);
      state = state.copyWith(isReceiving: true, errorMessage: null);
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
    );
  }

  void setUnitMs(int ms) {
    state = state.copyWith(unitMs: ms);
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
    if (decoder.pendingSymbols.isNotEmpty &&
        !detector.isOn &&
        _lastEventMs > 0 &&
        nowMs - _lastEventMs >= 7 * state.unitMs) {
      decoder.flush();
    }

    if (detector.isOn != state.isLightDetected ||
        decoder.pendingSymbols != state.currentSymbols) {
      state = state.copyWith(
        isLightDetected: detector.isOn,
        currentSymbols: decoder.pendingSymbols,
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
