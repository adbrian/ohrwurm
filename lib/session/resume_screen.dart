import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../library/library_controller.dart';
import '../library/widgets.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'launch.dart';
import 'session_cards.dart';
import 'session_widgets.dart';
import 'sessions.dart';
import 'setup_controller.dart';

/// Shown at launch when a session exists, before anything else (APP_SPEC 10.2, DESIGN 3).
class ResumeScreen extends StatefulWidget {
  final Session session;

  const ResumeScreen({super.key, required this.session});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  OpenedSession? _opened;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final opened = await context.read<Sessions>().open(widget.session);
    if (mounted) setState(() => _opened = opened);
  }

  Future<void> _resume() async {
    final setup = context.read<SetupController>();
    final changeSelection = await showSession(context, _opened!);
    if (changeSelection) setup.prefill(widget.session.options);
    setup.dismissResume();
  }

  @override
  Widget build(BuildContext context) {
    final setup = context.read<SetupController>();
    final packs = {for (final p in context.watch<LibraryController>().packs) p.packId: p};
    final session = widget.session;
    final opened = _opened;
    final total = opened?.cards.length ?? session.cardOrder.length;
    // The card it resumes on, counted from 1; the end card counts as the last.
    final position = total == 0 ? 0 : ((opened?.position ?? session.position) + 1).clamp(1, total);
    return AppPage(
      children: [
        const SizedBox(height: AppSpace.xxl),
        Text(
          SessionCopy.resumeKicker,
          style: AppTextStyles.kicker.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: AppSpace.lg),
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(packNames(session.options.packIds, packs), style: AppText.german(17)),
              const SizedBox(height: AppSpace.xs),
              Text(SessionCopy.summary(session.options), style: AppTextStyles.meta),
              const SizedBox(height: AppSpace.lg),
              Text(
                '$position of $total',
                style: AppText.german(32).copyWith(fontFeatures: AppText.tabular),
              ),
              const SizedBox(height: AppSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : position / total,
                  minHeight: 2,
                  color: AppColors.accent,
                  backgroundColor: AppColors.divider,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        if (opened != null && opened.mostlyGone) ...[
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: AppColors.divider, width: AppBorder.rule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(SessionCopy.mostlyGone, style: AppText.german(16)),
                const SizedBox(height: AppSpace.sm),
                Text(SessionCopy.mostlyGoneBody, style: AppTextStyles.body),
                const SizedBox(height: AppSpace.lg),
                OutlinedButton(
                  style: AppButtons.primary,
                  onPressed: setup.dismissResume,
                  child: const Text(SessionCopy.choosePacks),
                ),
              ],
            ),
          ),
        ] else ...[
          OutlinedButton(
            style: AppButtons.primary,
            onPressed: opened == null ? null : _resume,
            child: const Text(SessionCopy.resume),
          ),
          const SizedBox(height: AppSpace.sm),
          TextButton(onPressed: setup.dismissResume, child: const Text(SessionCopy.newSession)),
        ],
      ],
    );
  }
}
