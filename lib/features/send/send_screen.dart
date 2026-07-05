import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              decoration: const InputDecoration(
                labelText: '日本語テキスト',
                border: OutlineInputBorder(),
              ),
              onChanged: vm.updateInput,
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
            color: code != null ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
