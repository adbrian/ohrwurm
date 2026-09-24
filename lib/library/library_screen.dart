import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../packs/pack_display.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'library_controller.dart';
import 'widgets.dart';

/// The packs in the database, read-only in A2: cards per DESIGN 4 without selection, progress
/// or options, and a Rescan action (STATUS, 2026-09-24).
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    return AppPage(
      children: [
        Row(
          children: [
            Expanded(child: Text(Copy.libraryHeading, style: AppTextStyles.heading)),
            PlainIconButton(
              icon: AppIcons.rescan,
              tooltip: Copy.rescan,
              onPressed: library.scanning ? null : library.rescan,
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
            child: PackCard(pack),
          ),
      ],
    );
  }
}

/// One pack (DESIGN 4). An unavailable pack is still shown, in neutral-600, tagged *Not found*.
class PackCard extends StatelessWidget {
  final Pack pack;

  const PackCard(this.pack, {super.key});

  @override
  Widget build(BuildContext context) {
    final input = packInputOf(pack);
    final available = pack.available;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider, width: AppBorder.interactive),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  packHeading(input),
                  style: AppText.german(17).copyWith(
                    color: available ? AppColors.text : AppColors.neutral600,
                  ),
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
          if (!available) const _Tag(Copy.notFound),
        ],
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
