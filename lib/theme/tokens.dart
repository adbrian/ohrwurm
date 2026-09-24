import 'package:flutter/painting.dart';

/// Design tokens from docs/DESIGN.md. Widgets use these; they never hardcode colours or sizes.

abstract final class AppColors {
  static const bg = Color(0xFF0E0E13);
  static const surface = Color(0xFF17171F);
  static const surfaceRaised = Color(0xFF1F1F29);
  static const divider = Color(0xFF2C2C38);

  static const text = Color(0xFFECECF1);
  static const neutral300 = Color(0xFFB4B4C2);
  static const neutral400 = Color(0xFF8E8E9E);
  static const neutral500 = Color(0xFF6C6C7C);
  static const neutral600 = Color(0xFF4E4E5C);

  static const accent = Color(0xFF9184D9);
  static const accent300 = Color(0xFFB7AEF0);
  static const accent700 = Color(0xFF6A5FB3);
  static const accent800 = Color(0xFF4F4787);
  static const accent900 = Color(0xFF2E2A4D);

  /// The only accent fill allowed: a low-opacity tint (about 15%).
  static final accentTint = accent.withValues(alpha: 0.15);
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double card = 16;
  static const double tile = 12;
  static const double button = 12;

  /// Fully rounded: toggles and segmented controls.
  static const double pill = 999;
}

abstract final class AppBorder {
  /// Interactive elements.
  static const double interactive = 2;

  /// Dividers and rules.
  static const double rule = 1;
}
