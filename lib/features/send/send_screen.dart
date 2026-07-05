import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import 'send_view_model.dart';

class SendScreen extends ConsumerWidget {
  const SendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendViewModelProvider);
    final vm = ref.read(sendViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('モールス送信')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              enabled: !state.isSending,
              decoration: const InputDecoration(
                labelText: '日本語テキスト',
                border: OutlineInputBorder(),
              ),
              onChanged: vm.updateInput,
            ),
            const SizedBox(height: 16),
            _SpeedSlider(
              unitMs: state.unitMs,
              enabled: !state.isSending,
              onChanged: (ms) => vm.setUnitMs(ms),
            ),
            const SizedBox(height: 12),
            _SendButton(
              isSending: state.isSending,
              canSend: state.inputText.isNotEmpty,
              onStart: () => vm.startSending(),
              onStop: vm.stopSending,
            ),
            const SizedBox(height: 24),
            const Text('変換結果', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _MorseResultView(
                inputText: state.inputText,
                morseSequence: state.morseSequence,
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

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isSending,
    required this.canSend,
    required this.onStart,
    required this.onStop,
  });

  final bool isSending;
  final bool canSend;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSending ? onStop : (canSend ? onStart : null),
        style: isSending
            ? ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              )
            : null,
        icon: Icon(isSending ? Icons.stop : Icons.flash_on),
        label: Text(isSending ? '停止' : '送信'),
      ),
    );
  }
}

class _MorseResultView extends StatelessWidget {
  const _MorseResultView({
    required this.inputText,
    required this.morseSequence,
  });

  final String inputText;
  final List<String?> morseSequence;

  @override
  Widget build(BuildContext context) {
    if (inputText.isEmpty) {
      return const Center(
        child: Text('テキストを入力するとモールス符号が表示されます'),
      );
    }

    final chars = inputText.split('');
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (var i = 0; i < chars.length; i++)
            _MorseChip(char: chars[i], code: morseSequence[i]),
        ],
      ),
    );
  }
}

class _MorseChip extends StatelessWidget {
  const _MorseChip({required this.char, required this.code});

  final String char;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(char, style: theme.textTheme.titleMedium),
        Text(
          code ?? '?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: code != null
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
