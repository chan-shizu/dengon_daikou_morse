import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
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
              child: _DecodedTextView(
                decodedText: state.decodedText,
                currentSymbols: state.currentSymbols,
              ),
            ),
            const SizedBox(height: 12),
            _SpeedSlider(
              unitMs: state.unitMs,
              enabled: !state.isReceiving,
              onChanged: (ms) => vm.setUnitMs(ms),
            ),
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

class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider({
    required this.unitMs,
    required this.enabled,
    required this.onChanged,
  });

  final int unitMs;
  final bool enabled;
  final void Function(int ms) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('速度: ${unitMs}ms', style: Theme.of(context).textTheme.bodyMedium),
        Expanded(
          child: Slider(
            min: kMinUnitMs.toDouble(),
            max: kMaxUnitMs.toDouble(),
            divisions: (kMaxUnitMs - kMinUnitMs) ~/ 10,
            value: unitMs.toDouble(),
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
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
