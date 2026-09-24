import 'package:flutter/material.dart';

import 'tokens.dart';

/// Inter, bundled in assets/fonts. No network fonts.
const fontFamily = 'Inter';

/// Text styles. German is weight 500, English weight 400 — the only visual distinction between
/// the languages (DESIGN.md, Type).
abstract final class AppText {
  static TextStyle german(double size) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  static TextStyle english(double size) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral300,
  );

  /// For numbers that update in place: position, slider values.
  static const tabular = [FontFeature.tabularFigures()];
}

/// Buttons are outlined only; the accent is never a fill (DESIGN.md, Shape).
abstract final class AppButtons {
  static ButtonStyle _outlined(Color border, Color foreground) => OutlinedButton.styleFrom(
    foregroundColor: foreground,
    side: BorderSide(color: border, width: AppBorder.interactive),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
    textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500),
  );

  /// 2 px accent border, accent text. Use with [OutlinedButton].
  static final primary = _outlined(AppColors.accent, AppColors.accent);

  /// 2 px divider border, text colour. The default [OutlinedButton] style.
  static final secondary = _outlined(AppColors.divider, AppColors.text);

  /// Text only. The default [TextButton] style.
  static final ghost = TextButton.styleFrom(
    foregroundColor: AppColors.text,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
    textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w500),
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.bg,
    secondary: AppColors.accent300,
    onSecondary: AppColors.bg,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.neutral400,
    surfaceContainerHighest: AppColors.surfaceRaised,
    outline: AppColors.divider,
    outlineVariant: AppColors.divider,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: AppBorder.rule,
      space: AppBorder.rule,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: AppButtons.secondary),
    textButtonTheme: TextButtonThemeData(style: AppButtons.ghost),
  );
}
