import 'package:flutter/material.dart';
import 'features/send/send_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'モールス伝言代行',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        fontFamily: 'NotoSansJP',
      ),
      home: const SendScreen(),
    );
  }
}
