import 'package:flutter/material.dart';

/// ポップデザインの配色。アプリアイコンのシアン×イエローを基調に、
/// 白いカードと太い暗色アウトラインでステッカー風に仕上げる。
abstract final class GadgetColors {
  /// 画面全体の背景 — アイコンの背景と同じシアン
  static const chassis = Color(0xFF0CC0DF);

  /// カード面（セクションの下地）
  static const panel = Color(0xFFFFFFFF);

  /// アウトライン・本文テキストの暗色（ディスプレイの地色と共通）
  static const ink = Color(0xFF0B3A46);

  /// ディスプレイの地色（暗いティール）
  static const lcdBackground = Color(0xFF0B3A46);

  /// イエロー発光（点灯）と消灯セグメント — アイコンのモールス符号と同色
  static const accent = Color(0xFFFFDE59);
  static const accentDim = Color(0xFF48634B);

  /// LED・ボタンの無効色（白カード上のグレー）
  static const ledOff = Color(0xFFC9DDE2);

  /// エラー・停止系の赤
  static const red = Color(0xFFFF5A5F);

  /// カード上のラベル（くすんだティール）
  static const label = Color(0xFF48808F);

  /// 暗い下地（ディスプレイ）上のラベル
  static const labelOnDark = Color(0xFF7FC4D4);
}

/// ディスプレイ・ラベル用のテキストスタイル
abstract final class GadgetTextStyles {
  static const _glow = [
    Shadow(color: Color(0x99FFDE59), blurRadius: 8),
  ];

  /// 計器表示（英数字・記号のみ。DSEG は日本語を持たない）
  static const lcd = TextStyle(
    fontFamily: 'DSEG14',
    color: GadgetColors.accent,
    shadows: _glow,
  );

  /// ディスプレイ上の日本語テキスト
  static const lcdJa = TextStyle(
    fontFamily: 'NotoSansJP',
    color: GadgetColors.accent,
    shadows: _glow,
  );

  /// カードの見出しラベル（英字想定）
  static const plate = TextStyle(
    color: GadgetColors.label,
    fontSize: 11,
    letterSpacing: 2,
    fontWeight: FontWeight.w800,
  );
}

ThemeData buildGadgetTheme() {
  const scheme = ColorScheme.light(
    primary: GadgetColors.accent,
    onPrimary: GadgetColors.ink,
    secondary: GadgetColors.accent,
    onSecondary: GadgetColors.ink,
    surface: GadgetColors.chassis,
    onSurface: GadgetColors.ink,
    surfaceContainerHighest: GadgetColors.panel,
    outline: GadgetColors.ink,
    outlineVariant: Color(0xFF0AAAC6),
    error: GadgetColors.red,
    onError: Colors.white,
  );

  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'NotoSansJP',
    scaffoldBackgroundColor: GadgetColors.chassis,
    appBarTheme: const AppBarTheme(
      backgroundColor: GadgetColors.chassis,
      foregroundColor: Colors.white,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansJP',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Colors.white,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: GadgetColors.panel,
        foregroundColor: GadgetColors.label,
        selectedBackgroundColor: GadgetColors.accent,
        selectedForegroundColor: GadgetColors.ink,
        side: const BorderSide(color: GadgetColors.ink, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        visualDensity: VisualDensity.compact,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: GadgetColors.accent,
      inactiveTrackColor: Color(0x66FFFFFF),
      thumbColor: Colors.white,
      activeTickMarkColor: Color(0x330B3A46),
      inactiveTickMarkColor: Color(0x66FFFFFF),
      trackHeight: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GadgetColors.lcdBackground,
      labelStyle: const TextStyle(color: GadgetColors.labelOnDark),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GadgetColors.accent, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GadgetColors.ink,
        side: const BorderSide(color: GadgetColors.ink, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: GadgetColors.label),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: GadgetColors.panel,
      indicatorColor: GadgetColors.accent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? GadgetColors.ink
              : GadgetColors.label,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: states.contains(WidgetState.selected)
              ? GadgetColors.ink
              : GadgetColors.label,
        ),
      ),
    ),
  );
}
