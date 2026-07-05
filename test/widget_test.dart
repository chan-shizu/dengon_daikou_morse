import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dengon_daikou_morse/app.dart';

void main() {
  testWidgets('SendScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    expect(find.text('モールス送信'), findsOneWidget);
  });
}
