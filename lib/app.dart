import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/receive/receive_screen.dart';
import 'features/receive/receive_view_model.dart';
import 'features/send/send_screen.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'モールス伝言代行',
      theme: buildGadgetTheme(),
      home: const HomeShell(),
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
