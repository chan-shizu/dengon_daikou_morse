import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/image/gray_image.dart';
import '../../core/morse/morse_encoder.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gadget/gadget_button.dart';
import '../../widgets/gadget/gadget_panel.dart';
import '../../widgets/gadget/lcd_display.dart';
import '../../widgets/gray_image_view.dart';
import 'send_view_model.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

// 入力が弾かれたときのアラート文言
String _rejectedInputMessage(MorseLanguage language) => switch (language) {
  MorseLanguage.japanese => '日本語モードでは ひらがな・カタカナ・数字・記号（. , ?）のみ入力できます',
  MorseLanguage.english => '英語モードでは 英字・数字・記号（. , ?）のみ入力できます',
};

String _removedBySwitchMessage(MorseLanguage language) =>
    '${language.label}モードで入力できない文字を削除しました';

class _SendScreenState extends ConsumerState<SendScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showAlert(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _onLanguageChanged(MorseLanguage language) {
    final vm = ref.read(sendViewModelProvider.notifier);
    final before = ref.read(sendViewModelProvider).inputText;
    vm.setLanguage(language);
    // 新しい言語で入力不能な文字は ViewModel 側で除去されるため、入力欄へ反映する
    final filtered = ref.read(sendViewModelProvider).inputText;
    if (_textController.text != filtered) {
      _textController.text = filtered;
    }
    if (before != filtered) {
      _showAlert(_removedBySwitchMessage(language));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendViewModelProvider);
    final vm = ref.read(sendViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('モールス送信'),
        actions: const [_PlateBadge('TX')],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        // キーボード表示などで高さが足りないときだけスクロール可能にする
        // （余裕があるときは Expanded がモールス表示を広げる従来のレイアウト）
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GadgetPanel(
                      label: 'INPUT',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ContentSelector(
                            content: state.content,
                            enabled: !state.isSending,
                            onChanged: vm.setContent,
                          ),
                          const SizedBox(height: 6),
                          if (state.content == SendContent.text) ...[
                            _LanguageSelector(
                              language: state.language,
                              enabled: !state.isSending,
                              onChanged: _onLanguageChanged,
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _textController,
                              enabled: !state.isSending,
                              style: GadgetTextStyles.lcdJa.copyWith(
                                fontSize: 16,
                              ),
                              cursorColor: GadgetColors.accent,
                              inputFormatters: [
                                _LanguageInputFormatter(
                                  state.language,
                                  onRejected: () => _showAlert(
                                    _rejectedInputMessage(state.language),
                                  ),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: '${state.language.label}テキスト',
                                isDense: true,
                              ),
                              onChanged: vm.updateInput,
                            ),
                          ] else
                            _ImagePickerRow(
                              enabled: !state.isSending,
                              quality: state.imageQuality,
                              onPick: vm.pickImage,
                              onQualityChanged: vm.setImageQuality,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    GadgetPanel(
                      label: 'SIGNAL / SPEED',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ModeSelector(
                            mode: state.mode,
                            enabled: !state.isSending,
                            onChanged: (mode) => vm.setMode(mode),
                          ),
                          if (state.mode == SendMode.sound)
                            // 音はトーン波形の一括再生なので光より大幅に速くできる
                            _SpeedSlider(
                              unitMs: state.soundUnitMs,
                              minMs: kSoundMinUnitMs,
                              maxMs: kSoundMaxUnitMs,
                              enabled: !state.isSending,
                              onChanged: (ms) => vm.setSoundUnitMs(ms),
                            )
                          else
                            _SpeedSlider(
                              unitMs: state.unitMs,
                              minMs: kMinUnitMs,
                              maxMs: kMaxUnitMs,
                              enabled: !state.isSending,
                              onChanged: (ms) => vm.setUnitMs(ms),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (state.isSending)
                      GadgetButton(
                        label: '停止',
                        subLabel: 'STOP',
                        icon: Icons.stop,
                        color: GadgetColors.red,
                        onPressed: vm.stopSending,
                      )
                    else
                      GadgetButton(
                        label: '送信',
                        subLabel: 'TRANSMIT',
                        icon: Icons.flash_on,
                        onPressed: state.canSend
                            ? () => vm.startSending()
                            : null,
                      ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: state.content == SendContent.text
                          ? LcdDisplay(
                              child: _MorseResultView(
                                inputText: state.inputText,
                                morseSequence: state.morseSequence,
                                sendingCharIndex: state.sendingCharIndex,
                              ),
                            )
                          : _ImagePreview(state: state),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        child: Text(text, style: GadgetTextStyles.lcd.copyWith(fontSize: 18)),
      ),
    );
  }
}

class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider({
    required this.unitMs,
    required this.minMs,
    required this.maxMs,
    required this.enabled,
    required this.onChanged,
  });

  final int unitMs;
  final int minMs;
  final int maxMs;
  final bool enabled;
  final void Function(int ms) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('SPEED', style: GadgetTextStyles.plate),
        Expanded(
          child: Slider(
            min: minMs.toDouble(),
            max: maxMs.toDouble(),
            divisions: (maxMs - minMs) ~/ 10,
            value: unitMs.toDouble(),
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
        ),
        SizedBox(
          width: 88,
          child: Text(
            '${unitMs}ms',
            textAlign: TextAlign.right,
            style: GadgetTextStyles.lcd.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// 選択言語で入力できない文字を弾くフォーマッタ。
/// IME 変換中（ローマ字の中間状態など）はフィルタせず、確定時に適用する。
class _LanguageInputFormatter extends TextInputFormatter {
  _LanguageInputFormatter(this.language, {this.onRejected});

  final MorseLanguage language;
  final VoidCallback? onRejected;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid) return newValue;

    final filtered = language.filterText(newValue.text);
    if (filtered == newValue.text) return newValue;

    onRejected?.call();
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

class _ContentSelector extends StatelessWidget {
  const _ContentSelector({
    required this.content,
    required this.enabled,
    required this.onChanged,
  });

  final SendContent content;
  final bool enabled;
  final void Function(SendContent content) onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SendContent>(
      segments: [
        for (final c in SendContent.values)
          ButtonSegment(value: c, label: Text(c.label)),
      ],
      selected: {content},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
    );
  }
}

/// 画像の選択元（フォルダ/カメラ）と画質の選択
class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.enabled,
    required this.quality,
    required this.onPick,
    required this.onQualityChanged,
  });

  final bool enabled;
  final GrayImageQuality quality;
  final void Function(ImageSource source) onPick;
  final void Function(GrayImageQuality quality) onQualityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? () => onPick(ImageSource.gallery) : null,
                icon: const Icon(Icons.photo_library),
                label: const Text('フォルダ'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? () => onPick(ImageSource.camera) : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('カメラ'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<GrayImageQuality>(
          segments: [
            for (final q in GrayImageQuality.values)
              ButtonSegment(
                value: q,
                label: Text('${q.label} ${q.longSide}px'),
              ),
          ],
          selected: {quality},
          onSelectionChanged: enabled
              ? (selection) => onQualityChanged(selection.first)
              : null,
        ),
      ],
    );
  }
}

/// 4階調変換後のプレビューと想定送信時間・送信進捗
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.state});

  final SendState state;

  @override
  Widget build(BuildContext context) {
    final image = state.image;

    if (image == null) {
      return const LcdDisplay(
        child: Center(
          child: Text(
            'フォルダまたはカメラから\n画像を選択してください',
            textAlign: TextAlign.center,
            style: TextStyle(color: GadgetColors.accentDim),
          ),
        ),
      );
    }

    final estimatedMs = state.estimatedImageMs!;
    return LcdDisplay(
      child: Column(
        children: [
          Expanded(
            child: Center(child: GrayImageView(image: image)),
          ),
          const SizedBox(height: 8),
          Text(
            '${image.width}×${image.height} / ${state.imagePayload.length}ビット / '
            '想定送信時間 ${_formatDuration(estimatedMs)}',
            style: GadgetTextStyles.lcdJa.copyWith(fontSize: 12),
          ),
          if (state.isSending) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.imagePayload.isEmpty
                  ? null
                  : state.sentBits / state.imagePayload.length,
              backgroundColor: GadgetColors.accentDim,
              color: GadgetColors.accent,
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    final minutes = seconds ~/ 60;
    return minutes > 0 ? '約$minutes分${seconds % 60}秒' : '約$seconds秒';
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.language,
    required this.enabled,
    required this.onChanged,
  });

  final MorseLanguage language;
  final bool enabled;
  final void Function(MorseLanguage language) onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MorseLanguage>(
      segments: [
        for (final l in MorseLanguage.values)
          ButtonSegment(value: l, label: Text(l.label)),
      ],
      selected: {language},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final SendMode mode;
  final bool enabled;
  final void Function(SendMode mode) onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SendMode>(
      segments: [
        for (final m in SendMode.values)
          ButtonSegment(value: m, label: Text(m.label)),
      ],
      selected: {mode},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
    );
  }
}

class _MorseResultView extends StatelessWidget {
  const _MorseResultView({
    required this.inputText,
    required this.morseSequence,
    required this.sendingCharIndex,
  });

  final String inputText;
  final List<String?> morseSequence;
  final int? sendingCharIndex;

  @override
  Widget build(BuildContext context) {
    if (inputText.isEmpty) {
      return const Center(
        child: Text(
          'テキストを入力すると\nモールス符号が表示されます',
          textAlign: TextAlign.center,
          style: TextStyle(color: GadgetColors.accentDim),
        ),
      );
    }

    final chars = inputText.split('');
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (var i = 0; i < chars.length; i++)
            _MorseChip(
              char: chars[i],
              code: morseSequence[i],
              isSending: i == sendingCharIndex,
            ),
        ],
      ),
    );
  }
}

class _MorseChip extends StatelessWidget {
  const _MorseChip({
    required this.char,
    required this.code,
    required this.isSending,
  });

  final String char;
  final String? code;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    // 送信中の文字は反転表示（イエロー地に暗色文字）
    final charStyle = GadgetTextStyles.lcdJa.copyWith(
      fontSize: 16,
      color: isSending ? GadgetColors.ink : GadgetColors.accent,
      shadows: isSending ? const [] : null,
    );
    final codeStyle = GadgetTextStyles.lcd.copyWith(
      fontSize: 12,
      color: isSending
          ? GadgetColors.ink
          : (code != null ? GadgetColors.accent : GadgetColors.red),
      shadows: isSending ? const [] : null,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isSending ? GadgetColors.accent : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(char, style: charStyle),
          Text(code ?? '?', style: codeStyle),
        ],
      ),
    );
  }
}
