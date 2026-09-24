import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// DESIGN's Phosphor icons, regular (stroked) weight, from the bundled Phosphor font
/// (`pubspec.yaml`). Codepoints as in phosphor_flutter 2.1.0's `PhosphorIconsRegular`.
abstract final class AppIcons {
  static const _family = 'Phosphor';

  static const headphones = IconData(0xe2a6, fontFamily: _family);
  static const folder = IconData(0xe24a, fontFamily: _family);
  static const back = IconData(0xe058, fontFamily: _family); // arrow-left
  static const rescan = IconData(0xe036, fontFamily: _family); // arrow-clockwise
}

abstract final class AppTextStyles {
  static final heading = AppText.german(24).copyWith(height: 1.25);
  static final body = AppText.english(15).copyWith(height: 1.45);
  static const meta = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.neutral500,
  );
  static const kicker = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    color: AppColors.neutral500,
  );
}

/// A scrolling screen with the standard padding and an optional leading button.
class AppPage extends StatelessWidget {
  final List<Widget> children;
  final Widget? leading;

  const AppPage({super.key, required this.children, this.leading});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.xl),
          children: [
            if (leading != null)
              Align(alignment: Alignment.centerLeft, child: leading!),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// An icon button in the current text colour.
class PlainIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const PlainIconButton({super.key, required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        color: AppColors.text,
        disabledColor: AppColors.neutral600,
        onPressed: onPressed,
      );
}

/// The folder location in a surface tile (DESIGN 2).
class FolderTile extends StatelessWidget {
  final String location;

  const FolderTile({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.folder, size: 20, color: AppColors.neutral400),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(location, style: AppText.english(15))),
        ],
      ),
    );
  }
}

enum DiscStyle {
  /// Filled accent: added, updated.
  filledAccent,

  /// Hollow neutral: unchanged.
  hollow,

  /// Ringed neutral: not loaded, not found.
  ringed,

  /// Neutral-600 hollow: skipped.
  faint,
}

/// A rescan row's status disc (DESIGN 2).
class StatusDisc extends StatelessWidget {
  final DiscStyle style;

  const StatusDisc(this.style, {super.key});

  static const double size = 12;

  @override
  Widget build(BuildContext context) {
    final decoration = switch (style) {
      DiscStyle.filledAccent => const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
      DiscStyle.hollow => BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.neutral400, width: 1.5),
        ),
      DiscStyle.ringed => BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.neutral400, width: 3),
        ),
      DiscStyle.faint => BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.neutral600, width: 1.5),
        ),
    };
    return Container(width: size, height: size, decoration: decoration);
  }
}

/// The verdict panel: accent-tinted when everything is fine, neutral-bordered otherwise
/// (DESIGN 2).
class VerdictPanel extends StatelessWidget {
  final bool fine;
  final String message;
  final String action;
  final VoidCallback? onAction;

  const VerdictPanel({
    super.key,
    required this.fine,
    required this.message,
    required this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: fine ? AppColors.accentTint : null,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(
          color: fine ? AppColors.accent800 : AppColors.divider,
          width: AppBorder.rule,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: AppText.german(16)),
          const SizedBox(height: AppSpace.lg),
          OutlinedButton(
            style: fine ? AppButtons.primary : AppButtons.secondary,
            onPressed: onAction,
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
