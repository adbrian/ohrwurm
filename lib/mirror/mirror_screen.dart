import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../library/widgets.dart';
import '../playback/audio_host.dart';
import '../session/copy.dart';
import '../session/end_card.dart';
import '../session/listen_screen.dart';
import '../session/session_cards.dart';
import '../session/session_widgets.dart';
import '../settings/settings.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'mirror_controller.dart';
import 'recorder.dart';

/// The Mirror card (DESIGN 7): the Listen card's header and body without the line segments and
/// without auto-play, then a box per sentence to play, record and compare.
class MirrorScreen extends StatefulWidget {
  final MirrorController controller;
  final String packs;
  final VoidCallback onChangeSelection;

  const MirrorScreen({
    super.key,
    required this.controller,
    required this.packs,
    required this.onChangeSelection,
  });

  @override
  State<MirrorScreen> createState() => _MirrorScreenState();
}

class _MirrorScreenState extends State<MirrorScreen> {
  MirrorController get _c => widget.controller;
  late final AudioHost _host = context.read<AudioHost>();
  late final AppSettings _settings = context.read<AppSettings>();
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Interruption>? _interruptions;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _hidden, onShow: _shown);
    // Play and record while in Mirror (APP_SPEC 12).
    unawaited(_host.configure(record: true));
    _interruptions = _host.interruptions.listen((e) {
      if (e == Interruption.pauseBegin) unawaited(_c.pause());
    });
    unawaited(_host.keepScreenOn(_settings.keepScreenOn));
  }

  void _hidden() {
    unawaited(_c.pause());
    unawaited(_host.keepScreenOn(false));
  }

  void _shown() => unawaited(_host.keepScreenOn(_settings.keepScreenOn));

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_interruptions?.cancel());
    unawaited(_c.close());
    unawaited(_host.keepScreenOn(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final card = _c.card;
        final number = _c.atEnd ? _c.length : _c.position + 1;
        final options = _c.session.options;
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SessionHeader(
                  packs: widget.packs,
                  detail:
                      '${SessionCopy.cardOf(number, _c.length)} · '
                      '${SessionCopy.orderOption(options.deckOrder).toLowerCase()}',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: AppSpace.sm),
                Expanded(
                  child: SwipeCard(
                    cardKey: _c.atEnd ? 'end' : '${_c.session.createdAt} ${_c.position}',
                    onSwipe: _c.atEnd ? null : _c.swipe,
                    child: card == null
                        ? EndCard(
                            packs: widget.packs,
                            options: options,
                            cards: _c.length,
                            onRestart: _c.restart,
                            onReshuffle: _c.reshuffle,
                            onChangeSelection: widget.onChangeSelection,
                          )
                        : _MirrorCardView(controller: _c, card: card),
                  ),
                ),
                if (card != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    SessionCopy.mirrorHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.meta,
                  ),
                ],
                const SizedBox(height: AppSpace.md),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MirrorCardView extends StatelessWidget {
  final MirrorController controller;
  final SessionCard card;

  const _MirrorCardView({required this.controller, required this.card});

  @override
  Widget build(BuildContext context) {
    final content = card.content;
    final grammar = content.grammarLine;
    final boxes = controller.boxes;
    return SurfaceCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, AppSpace.xl, AppSpace.lg, AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: HighlightLine.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(content.word.text, style: AppText.german(30).copyWith(height: 1.2)),
                  const SizedBox(height: AppSpace.xs),
                  Text(content.translation.text, style: AppText.english(15)),
                  if (grammar != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(grammar, style: AppTextStyles.meta.copyWith(color: AppColors.neutral400)),
                  ],
                  if (controller.alsoIn.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    OutlinedTag('also in ${alsoInLabel(controller.alsoIn, card.packId)}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            for (final (i, box) in boxes.indexed)
              Padding(
                padding: const EdgeInsets.only(left: AppSpace.lg, bottom: AppSpace.md),
                child: MirrorBoxView(controller: controller, index: i, box: box),
              ),
          ],
        ),
      ),
    );
  }
}

/// A surface tile with a 1 px divider border: German line, English beneath, and **Play**,
/// **Record**, **Play mine** (DESIGN 7).
class MirrorBoxView extends StatelessWidget {
  final MirrorController controller;
  final int index;
  final MirrorBox box;

  const MirrorBoxView({
    super.key,
    required this.controller,
    required this.index,
    required this.box,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final active = c.activeBox == index;
    final recording = active && c.activity == BoxActivity.recording;
    final playing =
        active &&
        (c.activity == BoxActivity.playingGerman || c.activity == BoxActivity.playingMine);
    final refused = c.micRefusedIn(index);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(0, AppSpace.md, AppSpace.md, AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(
          color: recording ? AppColors.accent : AppColors.divider,
          width: AppBorder.rule,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (box.label != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.lg, bottom: AppSpace.xs),
              child: Text(
                box.label == 'question' ? SessionCopy.question : SessionCopy.answer,
                style: AppTextStyles.kicker.copyWith(fontSize: 11),
              ),
            ),
          // While either voice plays, the German line takes the active-line treatment.
          HighlightLine(
            text: box.pair.source.text,
            style: AppText.german(15),
            state: playing ? LineState.active : LineState.rest,
          ),
          const SizedBox(height: AppSpace.xs),
          Padding(
            padding: const EdgeInsets.only(left: HighlightLine.gutter),
            child: Text(box.pair.target.text, style: AppText.english(15)),
          ),
          const SizedBox(height: AppSpace.md),
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.lg),
            child: Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                _BoxButton(
                  icon: AppIcons.play,
                  label: SessionCopy.play,
                  onPressed: () => c.play(index),
                ),
                if (recording)
                  _BoxButton(
                    icon: AppIcons.stop,
                    label: '${SessionCopy.stop} · ${_time(c.elapsed)}',
                    accent: true,
                    onPressed: c.stopRecording,
                  )
                else
                  _BoxButton(
                    icon: AppIcons.record,
                    label: SessionCopy.record,
                    onPressed: () => c.record(index),
                  ),
                if (c.hasRecording(index))
                  _BoxButton(
                    icon: AppIcons.playMine,
                    label: SessionCopy.playMine,
                    onPressed: () => c.playMine(index),
                  ),
              ],
            ),
          ),
          if (refused != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    refused == MicAccess.deniedForever
                        ? SessionCopy.micDeniedForever
                        : SessionCopy.micDenied,
                    style: AppTextStyles.meta.copyWith(color: AppColors.neutral400),
                  ),
                  if (refused == MicAccess.deniedForever)
                    TextButton(
                      onPressed: c.openSettings,
                      child: const Text(SessionCopy.openSettings),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _time(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _BoxButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  final VoidCallback onPressed;

  const _BoxButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: (accent ? AppButtons.primary : AppButtons.secondary).copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        ),
        textStyle: WidgetStatePropertyAll(
          AppText.german(14).copyWith(fontFeatures: AppText.tabular),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
