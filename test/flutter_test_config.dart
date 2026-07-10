import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadFont(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      final data = File(asset).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(data.buffer)));
    }
    await loader.load();
  }

  await loadFont('NotoSansJP', ['assets/fonts/NotoSansJP.ttf']);
  await loadFont('DSEG14', [
    'assets/fonts/DSEG14Classic-Regular.ttf',
    'assets/fonts/DSEG14Classic-Bold.ttf',
  ]);

  await testMain();
}
