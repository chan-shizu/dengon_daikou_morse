import 'package:dengon_daikou_morse/app.dart';
import 'package:dengon_daikou_morse/features/onboarding/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();
  }

  testWidgets('初回起動時はオンボーディングが表示される', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('モールスで伝言しよう'), findsOneWidget);
  });

  testWidgets('「次へ」で3ページ進み「はじめる」で本編に入る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);

    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.text('光で送る'), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.text('音で送る'), findsOneWidget);

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('モールス送信'), findsOneWidget);

    // フラグが保存されている
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('スキップでも本編に入りフラグが保存される', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);

    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();
    expect(find.text('モールス送信'), findsOneWidget);
  });

  testWidgets('表示済みなら最初から本編が表示される', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await pumpApp(tester);

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('モールス送信'), findsOneWidget);
  });

  testWidgets('「?」からの再表示は「とじる」で戻りフラグを変えない', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await pumpApp(tester);

    await tester.tap(find.byTooltip('使い方'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('とじる'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('モールス送信'), findsOneWidget);
  });
}
