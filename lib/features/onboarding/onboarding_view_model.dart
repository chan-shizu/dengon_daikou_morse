import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_view_model.g.dart';

/// 初回起動時オンボーディングの表示済みフラグ。
/// true になるまで App はオンボーディング画面を表示する。
@riverpod
class OnboardingViewModel extends _$OnboardingViewModel {
  static const _seenKey = 'onboarding_seen';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    state = const AsyncData(true);
  }
}
