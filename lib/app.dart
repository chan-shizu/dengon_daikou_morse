import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/onboarding_view_model.dart';
import 'features/receive/receive_screen.dart';
import 'features/receive/receive_view_model.dart';
import 'features/send/send_screen.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'モールス伝言代行',
      theme: buildGadgetTheme(),
      home: switch (ref.watch(onboardingViewModelProvider)) {
        AsyncData(value: false) => const OnboardingScreen(),
        AsyncData(value: true) => const HomeShell(),
        // フラグ読み込み中（一瞬）は背景色だけの画面
        _ => const Scaffold(body: SizedBox.shrink()),
      },
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          SendScreen(),
          ReceiveScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 72,
        onDestinationSelected: (index) {
          // 受信タブから離れたらカメラを解放する
          if (_index == 1 && index != 1) {
            ref.read(receiveViewModelProvider.notifier).stopReceiving();
          }
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.flash_on), label: 'TX 送信'),
          NavigationDestination(icon: Icon(Icons.settings_input_antenna), label: 'RX 受信'),
        ],
      ),
    );
  }
}
