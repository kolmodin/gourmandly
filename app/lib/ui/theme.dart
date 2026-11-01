import 'package:flutter/material.dart';

/// The look of enamelware: cool white, a cobalt rim, and the food for colour.
abstract final class Palette {
  static const enamel = Color(0xFFF4F7F6);
  static const plate = Color(0xFFFFFFFF);
  static const cobalt = Color(0xFF1C3FAA);
  static const ink = Color(0xFF141E33);
  static const pewter = Color(0xFF5B6679);
  static const hairline = Color(0xFFDCE2E5);
  static const saffron = Color(0xFFE8A317);
  static const saffronInk = Color(0xFF7A5200);
}

abstract final class Fonts {
  static const _sans = 'Familjen Grotesk';

  static TextStyle serif(double size, {double height = 1.15}) => TextStyle(
    fontFamily: 'Young Serif',
    fontSize: size,
    height: height,
    color: Palette.ink,
  );

  static TextStyle sans(
    double size, {
    double weight = 400,
    double height = 1.35,
    Color color = Palette.ink,
  }) => TextStyle(
    fontFamily: _sans,
    fontSize: size,
    height: height,
    color: color,
    fontVariations: [FontVariation.weight(weight)],
  );
}

/// Wider than this, screens use a rail and two columns.
const wideBreakpoint = 840.0;

ThemeData gourmandlyTheme() {
  final base = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Palette.cobalt,
      onPrimary: Palette.plate,
      secondary: Palette.saffron,
      onSecondary: Palette.ink,
      surface: Palette.enamel,
      onSurface: Palette.ink,
      surfaceContainerHighest: Palette.plate,
      outline: Palette.hairline,
    ),
    fontFamily: 'Familjen Grotesk',
    scaffoldBackgroundColor: Palette.enamel,
    splashFactory: InkSparkle.splashFactory,
  );
  const pill = StadiumBorder();
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: Fonts.sans(17),
      bodyMedium: Fonts.sans(15),
      bodySmall: Fonts.sans(13, color: Palette.pewter),
      titleMedium: Fonts.sans(17, weight: 600),
      labelLarge: Fonts.sans(15, weight: 600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: Fonts.sans(16, weight: 600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        foregroundColor: Palette.cobalt,
        side: const BorderSide(color: Palette.cobalt, width: 1.5),
        textStyle: Fonts.sans(16, weight: 600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.cobalt,
        textStyle: Fonts.sans(15, weight: 600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.plate,
      hintStyle: Fonts.sans(16, color: Palette.pewter),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: Palette.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: Palette.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: Palette.cobalt, width: 1.5),
      ),
    ),
    // Saffron means cooking now, and nothing else.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Palette.cobalt
              : Palette.plate,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Palette.plate
              : Palette.ink,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: Palette.hairline)),
        textStyle: WidgetStatePropertyAll(Fonts.sans(15, weight: 600)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Palette.plate,
      selectedColor: Palette.cobalt,
      labelStyle: Fonts.sans(14),
      secondaryLabelStyle: Fonts.sans(14, color: Palette.plate),
      checkmarkColor: Palette.plate,
      side: const BorderSide(color: Palette.hairline),
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.enamel,
      indicatorColor: Palette.cobalt.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(Fonts.sans(13, weight: 600)),
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Palette.enamel,
      indicatorColor: Palette.cobalt.withValues(alpha: 0.12),
      selectedLabelTextStyle: Fonts.sans(13, weight: 600),
      unselectedLabelTextStyle: Fonts.sans(13, color: Palette.pewter),
      labelType: NavigationRailLabelType.all,
    ),
    dividerTheme: const DividerThemeData(color: Palette.hairline, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.ink,
      contentTextStyle: Fonts.sans(15, color: Palette.plate),
      actionTextColor: Palette.saffron,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
