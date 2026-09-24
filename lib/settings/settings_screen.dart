import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../library/copy.dart';
import '../library/library_controller.dart';
import '../library/widgets.dart';
import '../session/copy.dart';
import '../session/setup_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'settings.dart';

abstract final class SettingsCopy {
  static const heading = 'Settings';
  static const pauses = 'PAUSES';
  static const speed = 'SPEED';
  static const packs = 'PACKS';
  static const keepScreenOn = 'Keep screen on during sessions';
  static const changeFolder = 'Change folder';

  static String pauseLabel(PauseKind k) => switch (k) {
    PauseKind.afterWord => 'After the German word',
    PauseKind.afterTranslation => 'After the English meaning',
    PauseKind.afterGermanSentence => 'After a German sentence',
    PauseKind.afterEnglishSentence => 'After an English sentence',
    PauseKind.betweenCards => 'Between cards',
  };

  /// One line of rationale per pause; the German-sentence pause gets the most words (DESIGN 9).
  static String pauseWhy(PauseKind k) => switch (k) {
    PauseKind.afterWord => 'Time to take in the word before its meaning.',
    PauseKind.afterTranslation => 'Let the meaning settle before the example.',
    PauseKind.afterGermanSentence =>
      'The pause that does the teaching. Understand it before the English arrives.',
    PauseKind.afterEnglishSentence => 'A breath before the next line.',
    PauseKind.betweenCards => 'Before the card repeats, or the next one comes.',
  };

  static String seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

  static String speedLabel(double s) => switch (s) {
    0.75 => '0.75×',
    1.25 => '1.25×',
    _ => '1×',
  };
}

/// Settings (APP_SPEC 14, DESIGN 9): pauses, speed, keep screen on, and the pack folder.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final library = context.watch<LibraryController>();
    final navigator = Navigator.of(context);
    return AppPage(
      leading: PlainIconButton(
        icon: AppIcons.back,
        tooltip: SessionCopy.back,
        onPressed: () => navigator.maybePop(),
      ),
      children: [
        const SizedBox(height: AppSpace.sm),
        Text(SettingsCopy.heading, style: AppTextStyles.heading),
        const SizedBox(height: AppSpace.xl),
        Text(SettingsCopy.pauses, style: AppTextStyles.kicker),
        const SizedBox(height: AppSpace.md),
        for (final kind in PauseKind.values) _PauseSlider(kind: kind, settings: settings),
        const SizedBox(height: AppSpace.lg),
        Text(SettingsCopy.speed, style: AppTextStyles.kicker),
        const SizedBox(height: AppSpace.md),
        Segmented<double>(
          values: speeds,
          selected: settings.speed,
          label: SettingsCopy.speedLabel,
          onChanged: settings.setSpeed,
        ),
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            Expanded(child: Text(SettingsCopy.keepScreenOn, style: AppText.german(15))),
            PillSwitch(value: settings.keepScreenOn, onChanged: settings.setKeepScreenOn),
          ],
        ),
        const SizedBox(height: AppSpace.xxl),
        Text(SettingsCopy.packs, style: AppTextStyles.kicker),
        const SizedBox(height: AppSpace.md),
        if (library.location != null) FolderTile(location: library.location!),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: library.scanning
                    ? null
                    : () {
                        // The result screen shows beneath.
                        navigator.pop();
                        library.rescan();
                      },
                child: const Text(Copy.rescan),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: OutlinedButton(
                onPressed: library.scanning
                    ? null
                    : () async {
                        navigator.pop();
                        await library.chooseFolder();
                      },
                child: const Text(SettingsCopy.changeFolder),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PauseSlider extends StatelessWidget {
  final PauseKind kind;
  final AppSettings settings;

  const _PauseSlider({required this.kind, required this.settings});

  @override
  Widget build(BuildContext context) {
    final ms = settings.pauseMs(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(SettingsCopy.pauseLabel(kind), style: AppText.german(15))),
              Text(
                SettingsCopy.seconds(ms),
                style: AppText.german(15)
                    .copyWith(color: AppColors.accent300, fontFeatures: AppText.tabular),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(SettingsCopy.pauseWhy(kind), style: AppTextStyles.meta),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.divider,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accentTint,
              trackHeight: 2,
            ),
            child: Slider(
              value: ms.toDouble(),
              min: AppSettings.minPauseMs.toDouble(),
              max: AppSettings.maxPauseMs.toDouble(),
              divisions:
                  (AppSettings.maxPauseMs - AppSettings.minPauseMs) ~/ AppSettings.pauseStepMs,
              label: SettingsCopy.seconds(ms),
              onChanged: (v) => settings.setPause(kind, v.round()),
            ),
          ),
        ],
      ),
    );
  }
}
