import 'package:flutter/material.dart';

import '../data/models.dart';
import '../library/widgets.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'session_widgets.dart';

/// After the last card, reached by swiping like any card; not a modal (APP_SPEC 10.3, DESIGN 8).
/// No statistics: they aren't tracked.
class EndCard extends StatefulWidget {
  final String packs;
  final SessionOptions options;
  final int cards;
  final Future<void> Function() onRestart;
  final Future<void> Function() onReshuffle;
  final VoidCallback onChangeSelection;

  const EndCard({
    super.key,
    required this.packs,
    required this.options,
    required this.cards,
    required this.onRestart,
    required this.onReshuffle,
    required this.onChangeSelection,
  });

  @override
  State<EndCard> createState() => _EndCardState();
}

class _EndCardState extends State<EndCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          Text(
            SessionCopy.sessionDone,
            style: AppTextStyles.kicker.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(SessionCopy.endHeading, style: AppTextStyles.heading),
          const SizedBox(height: AppSpace.xl),
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: AppColors.divider, width: AppBorder.rule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.packs, style: AppText.german(15)),
                const SizedBox(height: AppSpace.xs),
                Text(SessionCopy.summary(widget.options), style: AppTextStyles.meta),
                const SizedBox(height: AppSpace.xs),
                Text(
                  SessionCopy.cards(widget.cards),
                  style: AppTextStyles.meta.copyWith(fontFeatures: AppText.tabular),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          OutlinedButton(
            style: AppButtons.primary,
            onPressed: _busy ? null : () => _run(widget.onRestart),
            child: const Text(SessionCopy.restart),
          ),
          const SizedBox(height: AppSpace.md),
          OutlinedButton(
            onPressed: _busy ? null : () => _run(widget.onReshuffle),
            child: const Text(SessionCopy.reshuffle),
          ),
          const SizedBox(height: AppSpace.sm),
          TextButton(
            onPressed: _busy ? null : widget.onChangeSelection,
            child: const Text(SessionCopy.changeSelection),
          ),
        ],
      ),
    );
  }
}
