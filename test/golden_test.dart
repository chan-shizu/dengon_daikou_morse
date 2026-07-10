import 'package:dengon_daikou_morse/app.dart';
import 'package:dengon_daikou_morse/features/receive/receive_screen.dart';
import 'package:dengon_daikou_morse/features/send/send_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// iPhone 15 Pro サイズで固定
const _kSurfaceSize = Size(393, 852);

Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(_kSurfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  group('SendScreen golden', () {
    testWidgets('初期状態（入力なし）', (tester) async {
      await _pumpApp(tester, const ProviderScope(child: App()));

      await expectLater(
        find.byType(SendScreen),
        matchesGoldenFile('goldens/send_screen_empty.png'),
      );
    });

    testWidgets('日本語入力後', (tester) async {
      await _pumpApp(tester, const ProviderScope(child: App()));

      await tester.enterText(find.byType(TextField), 'モールス');
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SendScreen),
        matchesGoldenFile('goldens/send_screen_katakana.png'),
      );
    });

    testWidgets('変換不能文字を含む入力', (tester) async {
      await _pumpApp(tester, const ProviderScope(child: App()));

      // 「ョ」は和文モールス表にないため ? になる
      await tester.enterText(find.byType(TextField), 'きょう');
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SendScreen),
        matchesGoldenFile('goldens/send_screen_with_unknown_char.png'),
      );
    });
  });

  group('ReceiveScreen golden', () {
    testWidgets('停止状態', (tester) async {
      await _pumpApp(tester, const ProviderScope(child: App()));

      await tester.tap(find.text('RX 受信'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ReceiveScreen),
        matchesGoldenFile('goldens/receive_screen_idle.png'),
      );
    });
  });
}
