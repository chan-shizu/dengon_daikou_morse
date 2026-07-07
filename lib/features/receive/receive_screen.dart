import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/image/gray_image.dart';
import '../../core/morse/morse_decoder.dart';
import '../../widgets/gray_image_view.dart';
import 'receive_view_model.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiveViewModelProvider);
    final vm = ref.read(receiveViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('モールス受信')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CameraPreviewArea(
              isReceiving: state.isReceiving,
              isLightDetected: state.isLightDetected,
              controller: vm.cameraController,
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: state.image != null
                  ? _ReceivedImageView(image: state.image!)
                  : _DecodedTextView(
                      decodedText: state.decodedText,
                      currentSymbols: state.currentSymbols,
                    ),
            ),
            const SizedBox(height: 12),
            _ProtocolStatus(state: state),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ReceiveButton(
                    isReceiving: state.isReceiving,
                    onStart: () => vm.startReceiving(),
                    onStop: () => vm.stopReceiving(),
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

class _CameraPreviewArea extends StatelessWidget {
  const _CameraPreviewArea({
    required this.isReceiving,
    required this.isLightDetected,
    required this.controller,
  });

  final bool isReceiving;
  final bool isLightDetected;
  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isReceiving && controller != null)
              CameraPreview(controller!)
            else
              ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Text('受信開始でカメラが起動します'),
                ),
              ),
            // 光検知インジケータ
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLightDetected
                      ? Colors.yellow
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(child: Center(child: GrayImageView(image: image))),
          const SizedBox(height: 8),
          Text(
            '${image.pixels.length} / ${image.pixelCount} 画素',
            style: theme.textTheme.bodyMedium,
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              decodedText.isEmpty ? '受信したテキストが表示されます' : decodedText,
              style: theme.textTheme.titleLarge?.copyWith(
                color: decodedText.isEmpty
                    ? theme.colorScheme.outline
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (currentSymbols.isNotEmpty)
              Text(
                currentSymbols,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
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
    final theme = Theme.of(context);

    final (icon, text) = switch (state.phase) {
      ReceivePhase.waitingSignal => state.isReceiving
          ? (Icons.hourglass_empty, '開始合図を待っています…')
          : (Icons.info_outline, '受信開始で相手の開始合図を待ちます（速度は自動検出）'),
      ReceivePhase.waitingHeader => (
          Icons.wifi_tethering,
          '合図を検出（単位 ${state.detectedUnitMs}ms）— ヘッダー符号待ち…',
        ),
      ReceivePhase.receivingBody => (
          Icons.podcasts,
          '受信中: ${state.language?.label}（単位 ${state.detectedUnitMs}ms）',
        ),
      ReceivePhase.receivingImageMeta => (
          Icons.image_outlined,
          '画像情報を受信中…（単位 ${state.detectedUnitMs}ms）',
        ),
      ReceivePhase.receivingImagePixels => (
          Icons.image_outlined,
          '画像受信中: ${state.image?.width}×${state.image?.height}'
              '（単位 ${state.detectedUnitMs}ms）',
        ),
      ReceivePhase.done => (
          Icons.check_circle_outline,
          state.image != null ? '画像の受信完了' : '受信完了（${state.language?.label}）',
        ),
    };

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _ReceiveButton extends StatelessWidget {
  const _ReceiveButton({
    required this.isReceiving,
    required this.onStart,
    required this.onStop,
  });

  final bool isReceiving;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isReceiving ? onStop : onStart,
      style: isReceiving
          ? ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            )
          : null,
      icon: Icon(isReceiving ? Icons.stop : Icons.videocam),
      label: Text(isReceiving ? '停止' : '受信開始'),
    );
  }
}
