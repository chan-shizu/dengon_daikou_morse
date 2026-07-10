import 'package:flutter/material.dart';

/// 無線機・トランシーバー風テーマの配色。
/// ダークな筐体にアンバー（琥珀色）の発光表示で統一する。
abstract final class GadgetColors {
  /// 筐体（画面全体の背景）
  static const chassis = Color(0xFF15181C);

  /// パネル面（セクションの下地）
  static const panel = Color(0xFF23272D);

  /// ベゼルの受光側/影側（面取りの立体感）
  static const bezelLight = Color(0xFF3D444D);
  static const bezelDark = Color(0xFF0A0C0E);

  /// LCD の地色（わずかに暖色の黒）
  static const lcdBackground = Color(0xFF120E06);

  /// アンバー発光（点灯）と消灯セグメント
  static const amber = Color(0xFFFFB000);
  static const amberDim = Color(0xFF453208);

  /// LED の消灯色
  static const ledOff = Color(0xFF3A3428);

  /// エラー・停止系の赤
  static const red = Color(0xFFFF4136);

  /// 銘板の刻印ラベル
  static const label = Color(0xFF8D97A3);
}

/// LCD・銘板用のテキストスタイル
abstract final class GadgetTextStyles {
  static const _glow = [
    Shadow(color: Color(0x99FFB000), blurRadius: 8),
  ];

  /// 計器表示（英数字・記号のみ。DSEG は日本語を持たない）
  static const lcd = TextStyle(
    fontFamily: 'DSEG14',
    color: GadgetColors.amber,
    shadows: _glow,
  );

  /// LCD 上の日本語テキスト
  static const lcdJa = TextStyle(
    fontFamily: 'NotoSansJP',
    color: GadgetColors.amber,
    shadows: _glow,
  );

  /// 銘板の刻印（英字ラベル）
  static const plate = TextStyle(
    color: GadgetColors.label,
    fontSize: 11,
    letterSpacing: 2,
    fontWeight: FontWeight.w600,
  );
}

ThemeData buildGadgetTheme() {
  const scheme = ColorScheme.dark(
    primary: GadgetColors.amber,
    onPrimary: Colors.black,
    secondary: GadgetColors.amber,
    onSecondary: Colors.black,
    surface: GadgetColors.chassis,
    onSurface: Color(0xFFD5DAE0),
    surfaceContainerHighest: GadgetColors.panel,
    outline: Color(0xFF4A525C),
    outlineVariant: Color(0xFF343B43),
    error: GadgetColors.red,
    onError: Colors.black,
  );

  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'NotoSansJP',
    scaffoldBackgroundColor: GadgetColors.chassis,
    appBarTheme: const AppBarTheme(
      backgroundColor: GadgetColors.chassis,
      foregroundColor: Color(0xFFD5DAE0),
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansJP',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: Color(0xFFD5DAE0),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: GadgetColors.bezelDark,
        foregroundColor: GadgetColors.label,
        selectedBackgroundColor: GadgetColors.panel,
        selectedForegroundColor: GadgetColors.amber,
        side: const BorderSide(color: Color(0xFF343B43)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        visualDensity: VisualDensity.compact,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: GadgetColors.amber,
      inactiveTrackColor: GadgetColors.bezelDark,
      thumbColor: Color(0xFFB9C2CC),
      activeTickMarkColor: Color(0x66000000),
      inactiveTickMarkColor: Color(0xFF343B43),
      trackHeight: 6,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GadgetColors.lcdBackground,
      labelStyle: const TextStyle(color: GadgetColors.label),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF343B43)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: GadgetColors.amber),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2A3037)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD5DAE0),
        side: const BorderSide(color: Color(0xFF4A525C)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: GadgetColors.label),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: GadgetColors.bezelDark,
      indicatorColor: GadgetColors.panel,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? GadgetColors.amber
              : GadgetColors.label,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: states.contains(WidgetState.selected)
              ? GadgetColors.amber
              : GadgetColors.label,
        ),
      ),
    ),
  );
}
