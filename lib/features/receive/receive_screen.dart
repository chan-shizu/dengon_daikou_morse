import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/image/gray_image.dart';
import '../../core/morse/morse_decoder.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gadget/gadget_button.dart';
import '../../widgets/gadget/gadget_panel.dart';
import '../../widgets/gadget/lcd_display.dart';
import '../../widgets/gadget/led_indicator.dart';
import '../../widgets/gray_image_view.dart';
import 'receive_view_model.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiveViewModelProvider);
    final vm = ref.read(receiveViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('モールス受信'),
        actions: const [_PlateBadge('RX')],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GadgetPanel(
              label: 'SIGNAL SOURCE',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SignalSelector(
                    signal: state.signal,
                    enabled: !state.isReceiving,
                    onChanged: vm.setSignal,
                  ),
                  const SizedBox(height: 10),
                  _SignalPreviewArea(
                    signal: state.signal,
                    isReceiving: state.isReceiving,
                    isDetected: state.isLightDetected,
                    controller: vm.cameraController,
                  ),
                ],
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: GadgetColors.red),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: state.image != null
                  ? _ReceivedImageView(image: state.image!)
                  : _DecodedTextView(
                      decodedText: state.decodedText,
                      currentSymbols: state.currentSymbols,
                    ),
            ),
            const SizedBox(height: 10),
            _ProtocolStatus(state: state),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: state.isReceiving
                      ? GadgetButton(
                          label: '停止',
                          subLabel: 'STOP',
                          icon: Icons.stop,
                          color: GadgetColors.red,
                          onPressed: () => vm.stopReceiving(),
                        )
                      : GadgetButton(
                          label: '受信開始',
                          subLabel: 'RECEIVE',
                          icon: Icons.settings_input_antenna,
                          onPressed: () => vm.startReceiving(),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: state.decodedText.isEmpty ? null : vm.clearText,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'クリア',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar 右端の銘板バッジ（TX/RX）
class _PlateBadge extends StatelessWidget {
  const _PlateBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Text(
          text,
          style: GadgetTextStyles.lcd.copyWith(fontSize: 18),
        ),
      ),
    );
  }
}

class _SignalSelector extends StatelessWidget {
  const _SignalSelector({
    required this.signal,
    required this.enabled,
    required this.onChanged,
  });

  final ReceiveSignal signal;
  final bool enabled;
  final void Function(ReceiveSignal signal) onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ReceiveSignal>(
      segments: [
        for (final s in ReceiveSignal.values)
          ButtonSegment(value: s, label: Text(s.label)),
      ],
      selected: {signal},
      onSelectionChanged:
          enabled ? (selection) => onChanged(selection.first) : null,
    );
  }
}

/// 光受信ならカメラプレビュー、音受信ならマイクの状態表示（モニター風ベゼル）
class _SignalPreviewArea extends StatelessWidget {
  const _SignalPreviewArea({
    required this.signal,
    required this.isReceiving,
    required this.isDetected,
    required this.controller,
  });

  final ReceiveSignal signal;
  final bool isReceiving;
  final bool isDetected;
  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (signal == ReceiveSignal.light && isReceiving && controller != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: GadgetColors.ink, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CameraPreview(controller!),
              ),
            )
          else
            LcdDisplay(
              child: Center(
                child: switch ((signal, isReceiving)) {
                  (ReceiveSignal.light, _) => const Text(
                      '受信開始でカメラが起動します',
                      style: TextStyle(color: GadgetColors.accentDim),
                    ),
                  (ReceiveSignal.sound, false) => const Text(
                      '受信開始でマイクが起動します',
                      style: TextStyle(color: GadgetColors.accentDim),
                    ),
                  (ReceiveSignal.sound, true) => Icon(
                      Icons.mic,
                      size: 48,
                      color: isDetected
                          ? GadgetColors.accent
                          : GadgetColors.accentDim,
                      shadows: isDetected
                          ? const [
                              Shadow(color: Color(0x99FFB000), blurRadius: 12)
                            ]
                          : null,
                    ),
                },
              ),
            ),
          // 信号検知LED
          Positioned(
            top: 8,
            right: 8,
            child: LedIndicator(isOn: isDetected, label: 'SIG'),
          ),
        ],
      ),
    );
  }
}

/// 受信中の画像を左上から逐次表示する（未受信部分はグレー）
class _ReceivedImageView extends StatelessWidget {
  const _ReceivedImageView({required this.image});

  final GrayImage image;

  @override
  Widget build(BuildContext context) {
    return LcdDisplay(
      child: Column(
        children: [
          Expanded(child: Center(child: GrayImageView(image: image))),
          const SizedBox(height: 8),
          Text(
            '${image.pixels.length} / ${image.pixelCount} 画素',
            style: GadgetTextStyles.lcdJa.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DecodedTextView extends StatelessWidget {
  const _DecodedTextView({
    required this.decodedText,
    required this.currentSymbols,
  });

  final String decodedText;
  final String currentSymbols;

  @override
  Widget build(BuildContext context) {
    return LcdDisplay(
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                decodedText.isEmpty ? '受信したテキストが表示されます' : decodedText,
                style: decodedText.isEmpty
                    ? const TextStyle(color: GadgetColors.accentDim)
                    : GadgetTextStyles.lcdJa.copyWith(fontSize: 22),
              ),
              if (currentSymbols.isNotEmpty)
                Text(
                  currentSymbols,
                  style: GadgetTextStyles.lcd.copyWith(fontSize: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// プロトコルの進行状況（合図待ち → 受信中 → 完了）を表示する。
/// 速度は開始合図から自動検出されるため、受信側にスライダーはない。
class _ProtocolStatus extends StatelessWidget {
  const _ProtocolStatus({required this.state});

  final ReceiveState state;

  @override
  Widget build(BuildContext context) {
    final text = switch (state.phase) {
      ReceivePhase.waitingSignal => state.isReceiving
          ? '開始合図を待っています…'
          : '受信開始で相手の開始合図を待ちます（速度は自動検出）',
      ReceivePhase.waitingHeader =>
        '合図を検出（単位 ${state.detectedUnitMs}ms）— ヘッダー符号待ち…',
      ReceivePhase.receivingBody =>
        '受信中: ${state.language?.label}（単位 ${state.detectedUnitMs}ms）',
      ReceivePhase.receivingImageMeta =>
        '画像情報を受信中…（単位 ${state.detectedUnitMs}ms）',
      ReceivePhase.receivingImagePixels =>
        '画像受信中: ${state.image?.width}×${state.image?.height}'
            '（単位 ${state.detectedUnitMs}ms）',
      ReceivePhase.done =>
        state.image != null ? '画像の受信完了' : '受信完了（${state.language?.label}）',
    };

    return GadgetPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          LedIndicator(
            isOn: state.isReceiving || state.phase == ReceivePhase.done,
            label: 'RX',
            onColor: state.phase == ReceivePhase.done
                ? const Color(0xFF4CD964)
                : GadgetColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB9C2CC)),
            ),
          ),
        ],
      ),
    );
  }
}
