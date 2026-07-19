import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

// オンボーディングを表示済みにして各画面を直接テストする
Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'onboarding_seen': true});
  await tester.pumpWidget(const ProviderScope(child: App()));
  await tester.pump();
}

void main() {
  testWidgets('SendScreen smoke test', (WidgetTester tester) async {
    await _pumpApp(tester);
    expect(find.text('モールス送信'), findsOneWidget);
  });

  group('言語別の入力制限', () {
    testWidgets('日本語モードでは英字を入力できず日本語のアラートが出る', (tester) async {
      await _pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'SOSあ1');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'あ1');
      expect(
        find.text('日本語モードでは ひらがな・カタカナ・数字・記号（. , ?）のみ入力できます'),
        findsOneWidget,
      );
    });

    testWidgets('英語モードではカナを入力できずアラートが出る', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('英語'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'SOSあ1');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'SOS1');
      expect(
        find.text('英語モードでは 英字・数字・記号（. , ?）のみ入力できます'),
        findsOneWidget,
      );
    });

    testWidgets('言語切替で入力不能になった文字は取り除かれアラートが出る', (tester) async {
      await _pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'あ1');
      await tester.pump();

      await tester.tap(find.text('英語'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '1');
      expect(
        find.text('英語モードで入力できない文字を削除しました'),
        findsOneWidget,
      );
    });
  });
}
