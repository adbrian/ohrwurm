import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../packs/rescanner.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'library_controller.dart';
import 'widgets.dart';

/// The folder and what the last rescan found in it (DESIGN 2). A broken pack is shown here,
/// rejected whole.
class RescanResultScreen extends StatelessWidget {
  const RescanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final report = library.report!;
    final v = verdict(report);
    final VoidCallback? action = library.scanning
        ? null
        : v.fine
            ? library.closeResult
            : library.rescan;
    // The back arrow and the system back both go to the library (STATUS, 2026-09-24).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) library.closeResult();
      },
      child: AppPage(
        leading: PlainIconButton(
          icon: AppIcons.back,
          tooltip: Copy.back,
          onPressed: library.closeResult,
        ),
        children: [
          const SizedBox(height: AppSpace.sm),
          FolderTile(location: library.location ?? ''),
          const SizedBox(height: AppSpace.lg),
          for (final row in report.rows) ResultRow(row),
          const SizedBox(height: AppSpace.lg),
          VerdictPanel(
            fine: v.fine,
            message: v.message,
            action: v.fine ? Copy.choosePacks : Copy.rescan,
            onAction: action,
          ),
        ],
      ),
    );
  }
}

class ResultRow extends StatelessWidget {
  final RescanRow row;

  const ResultRow(this.row, {super.key});

  @override
  Widget build(BuildContext context) {
    final disc = switch (row.outcome) {
      RescanOutcome.added || RescanOutcome.updated => DiscStyle.filledAccent,
      RescanOutcome.unchanged => DiscStyle.hollow,
      RescanOutcome.rejected || RescanOutcome.notFound => DiscStyle.ringed,
      RescanOutcome.skipped => DiscStyle.faint,
    };
    final faint = row.outcome == RescanOutcome.skipped;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 4), child: StatusDisc(disc)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rowName(row),
                  style: AppText.german(15)
                      .copyWith(color: faint ? AppColors.neutral500 : AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(rowDetail(row), style: AppTextStyles.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
