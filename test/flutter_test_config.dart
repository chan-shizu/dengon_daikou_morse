import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fontLoader = FontLoader('NotoSansJP');
  final fontData = File('assets/fonts/NotoSansJP.ttf').readAsBytesSync();
  fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
  await fontLoader.load();

  await testMain();
}
