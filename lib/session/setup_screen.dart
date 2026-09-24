import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../library/copy.dart';
import '../library/library_controller.dart';
import '../library/widgets.dart';
import '../packs/pack_display.dart';
import '../settings/settings_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'deck_builder.dart';
import 'launch.dart';
import 'setup_controller.dart';

/// Session setup, the main entry point (DESIGN 4): the packs, multi-select, then the options and
/// a footer with the live count and **Start**.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final setup = context.watch<SetupController>();
    final o = setup.options;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.xl),
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(SessionCopy.setupHeading, style: AppTextStyles.heading)),
                      PlainIconButton(
                        icon: AppIcons.rescan,
                        tooltip: Copy.rescan,
                        onPressed: library.scanning ? null : library.rescan,
                      ),
                      PlainIconButton(
                        icon: AppIcons.settings,
                        tooltip: SessionCopy.settings,
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    library.scanning ? Copy.checking : library.location ?? '',
                    style: AppTextStyles.meta,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (library.packs.isEmpty) Text(Copy.emptyLibrary, style: AppTextStyles.body),
                  for (final pack in library.packs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: PackCard(
                        pack,
                        rejected: library.wasRejected(pack),
                        selected: setup.isSelected(pack.packId),
                        progress: setup.packProgress(pack.packId),
                        onTap: pack.available ? () => setup.toggle(pack.packId) : null,
                      ),
                    ),
                  if (library.packs.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.lg),
                    const _Options(),
                  ],
                ],
              ),
            ),
            _Footer(setup: setup, options: o),
          ],
        ),
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options();

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<SetupController>();
    final o = setup.options;
    final listen = o.mode == SessionMode.listen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionRow(
          label: SessionCopy.mode,
          child: Segmented<SessionMode>(
            values: SessionMode.values,
            selected: o.mode,
            label: SessionCopy.modeOption,
            onChanged: setup.setMode,
          ),
        ),
        OptionRow(
          label: SessionCopy.words,
          child: Segmented<Words>(
            values: Words.values,
            selected: o.words,
            label: SessionCopy.wordsOption,
            onChanged: setup.setWords,
          ),
        ),
        if (focusApplies(o))
          OptionRow(
            label: SessionCopy.focus,
            child: Segmented<WordFocus>(
              values: WordFocus.values,
              selected: o.focus,
              label: SessionCopy.focusOption,
              onChanged: setup.setFocus,
            ),
          ),
        OptionRow(
          label: SessionCopy.style,
          child: Segmented<Style>(
            values: Style.values,
            selected: o.style,
            label: SessionCopy.styleOption,
            onChanged: setup.setStyle,
          ),
        ),
        if (listen && o.style == Style.qa)
          OptionRow(
            label: SessionCopy.qaTranslation,
            child: Segmented<QaTranslate>(
              values: QaTranslate.values,
              selected: o.qaTranslate,
              label: SessionCopy.qaOption,
              onChanged: setup.setQaTranslate,
            ),
          ),
        OptionRow(
          label: SessionCopy.deckOrder,
          child: Segmented<DeckOrder>(
            values: DeckOrder.values,
            selected: o.deckOrder,
            label: SessionCopy.orderOption,
            onChanged: setup.setDeckOrder,
          ),
        ),
        if (listen)
          OptionRow(
            label: SessionCopy.cardMode,
            child: Segmented<CardMode>(
              values: CardMode.values,
              selected: o.cardMode,
              label: SessionCopy.cardModeOption,
              onChanged: setup.setCardMode,
            ),
          ),
        OptionRow(
          label: SessionCopy.cardLimit,
          child: LimitStepper(
            limit: o.cardLimit,
            onLess: o.cardLimit == null ? null : setup.decreaseLimit,
            onMore: (o.cardLimit ?? 0) >= SetupController.maxLimit ? null : setup.increaseLimit,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          child: Row(
            children: [
              Expanded(child: Text(SessionCopy.unheardFirst, style: AppText.german(15))),
              PillSwitch(value: o.unheardFirst, onChanged: setup.setUnheardFirst),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final SetupController setup;
  final SessionOptions options;

  const _Footer({required this.setup, required this.options});

  Future<void> _start(BuildContext context) async {
    final changeSelection = await startSession(context, options);
    if (!context.mounted) return;
    // Pack progress changed while it played; the selection stays for the next session.
    if (!changeSelection) await setup.refresh();
    if (changeSelection) setup.prefill(options);
  }

  @override
  Widget build(BuildContext context) {
    final count = setup.count;
    final none = setup.selected.isNotEmpty && count == 0;
    final canStart = setup.selected.isNotEmpty && (count ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.lg),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider, width: AppBorder.rule),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  setup.selected.isEmpty
                      ? SessionCopy.footer(0, 0)
                      : SessionCopy.footer(setup.selected.length, count ?? 0),
                  style: AppText.german(15).copyWith(fontFeatures: AppText.tabular),
                ),
              ),
              OutlinedButton(
                style: AppButtons.primary,
                onPressed: canStart ? () => _start(context) : null,
                child: const Text(SessionCopy.start),
              ),
            ],
          ),
          if (none) ...[
            const SizedBox(height: AppSpace.sm),
            Text(SessionCopy.noCards(options), style: AppTextStyles.meta),
          ],
        ],
      ),
    );
  }
}

/// A labelled option (DESIGN 4).
class OptionRow extends StatelessWidget {
  final String label;
  final Widget child;

  const OptionRow({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.kicker),
          const SizedBox(height: AppSpace.sm),
          child,
        ],
      ),
    );
  }
}

/// A pill segmented control (DESIGN 4): the chosen value has an accent border, never a fill.
class Segmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final v in values)
          Semantics(
            button: true,
            selected: v == selected,
            child: GestureDetector(
              onTap: () => onChanged(v),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: v == selected ? AppColors.accent : AppColors.divider,
                    width: AppBorder.interactive,
                  ),
                ),
                child: Text(
                  label(v),
                  style: AppText.german(14)
                      .copyWith(color: v == selected ? AppColors.accent : AppColors.neutral400),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The card-limit stepper (DESIGN 4): *No limit*, or a number of cards.
class LimitStepper extends StatelessWidget {
  final int? limit;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  const LimitStepper({super.key, required this.limit, this.onLess, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.divider, width: AppBorder.interactive),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlainIconButton(icon: AppIcons.minus, tooltip: 'Fewer', onPressed: onLess),
          SizedBox(
            width: 96,
            child: Text(
              limit == null ? SessionCopy.noLimit : SessionCopy.cards(limit!),
              textAlign: TextAlign.center,
              style: AppText.german(14)
                  .copyWith(color: AppColors.accent300, fontFeatures: AppText.tabular),
            ),
          ),
          PlainIconButton(icon: AppIcons.plus, tooltip: 'More', onPressed: onMore),
        ],
      ),
    );
  }
}

/// A pill switch (DESIGN 4, 9): accent outline and knob when on, never a fill.
class PillSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const PillSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(4),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? AppColors.accentTint : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: value ? AppColors.accent : AppColors.divider,
              width: AppBorder.interactive,
            ),
          ),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.accent : AppColors.neutral500,
            ),
          ),
        ),
      ),
    );
  }
}

/// One pack (DESIGN 4): heading, meta line, progress as a thin bar with *34 / 80 heard*.
/// Selected: a 2 px accent border and a small accent check, never a fill. Unavailable:
/// neutral-600, tagged *Not found* or *Not loaded*, not selectable, still shown.
class PackCard extends StatelessWidget {
  final Pack pack;
  final bool rejected;
  final bool selected;
  final PackProgress? progress;
  final VoidCallback? onTap;

  const PackCard(
    this.pack, {
    super.key,
    this.rejected = false,
    this.selected = false,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final input = packInputOf(pack);
    final available = pack.available;
    final p = progress;
    return Semantics(
      button: available,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.divider,
              width: AppBorder.interactive,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          packHeading(input),
                          style: AppText.german(17)
                              .copyWith(color: available ? AppColors.text : AppColors.neutral600),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          packMeta(input, pack.cardCount),
                          style: AppTextStyles.meta.copyWith(
                            color: available ? AppColors.neutral500 : AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!available)
                    _Tag(rejected ? Copy.notLoaded : Copy.notFound)
                  else if (selected)
                    const Icon(AppIcons.check, size: 18, color: AppColors.accent),
                ],
              ),
              if (available && p != null && p.total > 0) ...[
                const SizedBox(height: AppSpace.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: p.heard / p.total,
                    minHeight: 3,
                    color: AppColors.accent,
                    backgroundColor: AppColors.divider,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  SessionCopy.heard(p.heard, p.total),
                  style: AppTextStyles.meta.copyWith(fontFeatures: AppText.tabular),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.neutral600, width: AppBorder.rule),
      ),
      child: Text(text, style: AppTextStyles.meta.copyWith(color: AppColors.neutral600)),
    );
  }
}
