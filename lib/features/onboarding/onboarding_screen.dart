import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/gadget/gadget_button.dart';
import 'onboarding_view_model.dart';

/// 初回起動時に表示する使い方説明（3ページのスワイプ形式）。
/// [isReplay] が true のときは「?」からの再表示で、閉じるだけでフラグを変えない。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.isReplay = false});

  final bool isReplay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _pages = [
  _OnboardingPage(
    icon: Icons.cell_tower,
    title: 'モールスで伝言しよう',
    description: '同じアプリを入れた2台の間で、\nモールス信号のメッセージを送り合えます。\n'
        '日本語・英語のテキストと、画像も送れます。',
  ),
  _OnboardingPage(
    icon: Icons.flash_on,
    title: '光で送る',
    description: 'フラッシュライトの点滅で送信し、\n相手のカメラで受信します。\n'
        '信号が目に見えて楽しい、基本のモードです。',
  ),
  _OnboardingPage(
    icon: Icons.music_note,
    title: '音で送る',
    description: 'トーン音で送信し、マイクで受信します。\n'
        '光よりずっと高速なので、サイズの大きい\n画像を送るときは音がおすすめです。',
  ),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _index == _pages.length - 1;

  void _finish() {
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      ref.read(onboardingViewModelProvider.notifier).markSeen();
    }
  }

  void _next() {
    if (_isLastPage) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  widget.isReplay ? 'とじる' : 'スキップ',
                  style: const TextStyle(
                    color: GadgetColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _PageBody(page: _pages[index]),
              ),
            ),
            _PageDots(current: _index),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: GadgetButton(
                  label: _isLastPage ? 'はじめる' : '次へ',
                  icon: _isLastPage ? Icons.check : Icons.arrow_forward,
                  onPressed: _next,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ステッカー風の丸アイコン
          Container(
            width: 160,
            height: 160,
            decoration: const BoxDecoration(
              color: GadgetColors.panel,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: GadgetColors.ink, width: 3),
              ),
              boxShadow: [
                BoxShadow(color: GadgetColors.ink, offset: Offset(0, 5)),
              ],
            ),
            child: Icon(page.icon, size: 80, color: GadgetColors.ink),
          ),
          const SizedBox(height: 36),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: GadgetColors.ink,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.8,
              fontWeight: FontWeight.w600,
              color: GadgetColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _pages.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 24 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i == current ? GadgetColors.accent : GadgetColors.panel,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: GadgetColors.ink, width: 1.5),
            ),
          ),
      ],
    );
  }
}
