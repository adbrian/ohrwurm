import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cards/recipe.dart';
import '../library/widgets.dart';
import '../playback/audio_host.dart';
import '../playback/listen_engine.dart';
import '../settings/settings.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'copy.dart';
import 'end_card.dart';
import 'listen_controller.dart';
import 'session_cards.dart';
import 'session_widgets.dart';

/// The Listen card, the product (DESIGN 5): the whole card is visible for as long as it plays,
/// and only the highlight moves.
class ListenScreen extends StatefulWidget {
  final ListenController controller;

  /// The session's pack names, for the header.
  final String packs;

  /// *Change selection* on the end card.
  final VoidCallback onChangeSelection;

  const ListenScreen({
    super.key,
    required this.controller,
    required this.packs,
    required this.onChangeSelection,
  });

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  ListenController get _c => widget.controller;
  late final AudioHost _host = context.read<AudioHost>();
  late final AppSettings _settings = context.read<AppSettings>();
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Interruption>? _interruptions;

  /// Stopped by a call, to restart when it ends.
  bool _interrupted = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _hidden, onShow: _shown);
    unawaited(_host.configure(record: false));
    _interruptions = _host.interruptions.listen(_interruption);
    unawaited(_host.keepScreenOn(_settings.keepScreenOn));
    _c.start();
  }

  /// The app went to the background: stop playback and let the screen sleep; on return the card
  /// restarts from its first line (APP_SPEC 11.5).
  void _hidden() {
    _c.stop();
    unawaited(_host.keepScreenOn(false));
  }

  void _shown() {
    unawaited(_host.keepScreenOn(_settings.keepScreenOn));
    if (!_interrupted) _c.start();
  }

  /// A call pauses the session and it resumes after; the card restarts from its first line
  /// (APP_SPEC 11.5).
  void _interruption(Interruption event) {
    switch (event) {
      case Interruption.pauseBegin:
        _interrupted = true;
        _c.stop();
      case Interruption.pauseEnd:
        if (!_interrupted) return;
        _interrupted = false;
        _c.start();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_interruptions?.cancel());
    _c.stop();
    unawaited(_host.keepScreenOn(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final engine = _c.engine;
        final options = _c.session.options;
        final card = _c.card;
        final number = _c.atEnd ? _c.length : _c.position + 1;
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
                  trailing: PillToggle(
                    label: SessionCopy.loop,
                    on: _c.cardMode == CardMode.looped,
                    onTap: _c.toggleLoop,
                  ),
                ),
                if (card != null)
                  LineSegments(
                    count: _c.deck.lines[_c.position].length,
                    active: engine.activeStep,
                    phase: engine.phase,
                  )
                else
                  const SizedBox(height: LineSegments.height + AppSpace.md),
                Expanded(
                  child: SwipeCard(
                    cardKey: _c.atEnd ? 'end' : '${_c.session.createdAt} ${_c.position}',
                    onSwipe: _c.atEnd ? null : _c.swipe,
                    onTap: _c.atEnd ? null : _c.replay,
                    child: card == null
                        ? EndCard(
                            packs: widget.packs,
                            options: options,
                            cards: _c.length,
                            onRestart: _c.restart,
                            onReshuffle: _c.reshuffle,
                            onChangeSelection: widget.onChangeSelection,
                          )
                        : ListenCardView(
                            card: card,
                            lines: _c.deck.lines[_c.position],
                            active: engine.activeStep,
                            phase: engine.phase,
                            alsoIn: _c.alsoIn,
                            status: _status(engine),
                          ),
                  ),
                ),
                if (card != null) ...[
                  const SizedBox(height: AppSpace.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _c.replay,
                            child: const Text(SessionCopy.again),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _c.swipe,
                            child: const Text(SessionCopy.next),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    SessionCopy.listenHint,
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

  /// The status line's copy (DESIGN 5, 6).
  ({String text, bool pulsing})? _status(ListenEngine engine) {
    if (engine.phase == ListenPhase.failed) return (text: SessionCopy.clipFailed, pulsing: false);
    if (_c.replaying) return (text: SessionCopy.replaying, pulsing: true);
    return switch (engine.phase) {
      ListenPhase.playing => (text: SessionCopy.listening, pulsing: true),
      ListenPhase.pause =>
        engine.pausedAfter == LineRole.germanSentence
            ? (text: SessionCopy.yourTurn, pulsing: false)
            : (text: SessionCopy.listening, pulsing: false),
      ListenPhase.gap =>
        _c.cardMode == CardMode.looped
            ? (text: SessionCopy.looping, pulsing: false)
            : (text: SessionCopy.movingOn, pulsing: false),
      ListenPhase.idle || ListenPhase.end || ListenPhase.failed => null,
    };
  }
}

/// One thin segment per line in the recipe: finished `accent700`, the current one `accent`,
/// upcoming `divider` (DESIGN 5).
class LineSegments extends StatelessWidget {
  final int count;
  final int? active;
  final ListenPhase phase;

  const LineSegments({super.key, required this.count, required this.active, required this.phase});

  static const double height = 3;

  @override
  Widget build(BuildContext context) {
    // In the gap, the whole card has played.
    final done = phase == ListenPhase.gap ? count : (active ?? 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.xs),
            Expanded(
              child: AnimatedContainer(
                key: ValueKey('segment $i'),
                duration: const Duration(milliseconds: 250),
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  color: i < done
                      ? AppColors.accent700
                      : i == active && phase != ListenPhase.gap
                      ? AppColors.accent
                      : AppColors.divider,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How a line looks: playing now, already played, or not yet (DESIGN 5).
enum LineState {
  active,
  played,
  upcoming,

  /// Mirror's German line when nothing plays: full colour, no mark.
  rest,
}

LineState lineState(int index, int? active, ListenPhase phase) {
  if (phase == ListenPhase.gap) return LineState.played;
  if (active == null || index > active) return LineState.upcoming;
  return index == active ? LineState.active : LineState.played;
}

/// The card body (DESIGN 5): headword, translation, grammar line, *also in* tag, a fading rule,
/// then the recipe's example lines, with the status line pinned to the bottom.
class ListenCardView extends StatelessWidget {
  final SessionCard card;
  final List<RecipeLine> lines;
  final int? active;
  final ListenPhase phase;
  final List<String> alsoIn;
  final ({String text, bool pulsing})? status;

  const ListenCardView({
    super.key,
    required this.card,
    required this.lines,
    required this.active,
    required this.phase,
    required this.alsoIn,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final content = card.content;
    final grammar = content.grammarLine;
    final pulsing = phase == ListenPhase.playing;
    Widget line(int i, TextStyle style) => HighlightLine(
      text: lines[i].line.text,
      style: style,
      state: lineState(i, active, phase),
      pulsing: pulsing,
    );

    final examples = <Widget>[];
    for (var i = 2; i < lines.length; i++) {
      final newGroup = lines[i].group != lines[i - 1].group;
      // 16 px between examples, 4 px within one (DESIGN 5); a Q&A's answer pair starts 8 px
      // below its question pair.
      final gap = newGroup
          ? (i == 2 ? 0.0 : AppSpace.lg)
          : (lines[i].german ? AppSpace.sm : AppSpace.xs);
      examples
        ..add(SizedBox(height: gap))
        ..add(line(i, lines[i].german ? AppText.german(15) : AppText.english(15)));
    }

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, AppSpace.xl, AppSpace.lg, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  line(0, AppText.german(30).copyWith(height: 1.2)),
                  const SizedBox(height: AppSpace.xs),
                  line(1, AppText.english(15)),
                  if (grammar != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(HighlightLine.gutter, AppSpace.sm, 0, 0),
                      child: Text(
                        grammar,
                        style: AppTextStyles.meta.copyWith(color: AppColors.neutral400),
                      ),
                    ),
                  if (alsoIn.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(HighlightLine.gutter, AppSpace.md, 0, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedTag('also in ${alsoInLabel(alsoIn, card.packId)}'),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(HighlightLine.gutter, AppSpace.lg, 0, AppSpace.lg),
                    child: FadingRule(),
                  ),
                  ...examples,
                ],
              ),
            ),
          ),
          StatusLine(status: status),
        ],
      ),
    );
  }
}

/// A line with the active-line treatment (DESIGN 5): a 2 px pulsing accent mark in the left
/// gutter and an accent tint behind it, bleeding slightly into the gutter. Colour and background
/// change over 250 ms; position and size never do.
class HighlightLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  final LineState state;
  final bool pulsing;

  const HighlightLine({
    super.key,
    required this.text,
    required this.style,
    required this.state,
    this.pulsing = true,
  });

  static const double gutter = AppSpace.xl;
  static const _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final active = state == LineState.active;
    final color = switch (state) {
      LineState.active || LineState.rest => AppColors.text,
      LineState.played => AppColors.neutral400,
      LineState.upcoming => AppColors.neutral500,
    };
    return Stack(
      children: [
        Positioned.fill(
          left: AppSpace.md,
          child: AnimatedContainer(
            duration: _duration,
            decoration: BoxDecoration(
              color: active ? AppColors.accentTint : AppColors.accentTint.withValues(alpha: 0),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.tile)),
            ),
          ),
        ),
        Positioned(
          left: AppSpace.md,
          top: 0,
          bottom: 0,
          width: 2,
          child: AnimatedOpacity(
            duration: _duration,
            opacity: active ? 1 : 0,
            child: Pulse(
              active: active && pulsing,
              child: const ColoredBox(color: AppColors.accent),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 2, AppSpace.sm, 2),
          child: AnimatedDefaultTextStyle(
            duration: _duration,
            style: style.copyWith(color: color),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}

/// Pinned to the card's bottom: a small dot, pulsing accent while a line plays and steady
/// dimmed accent otherwise, and one line of copy (DESIGN 5).
class StatusLine extends StatelessWidget {
  final ({String text, bool pulsing})? status;

  const StatusLine({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(HighlightLine.gutter, 0, AppSpace.lg, AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Opacity(
              opacity: s == null ? 0 : 1,
              child: Pulse(
                active: s?.pulsing ?? false,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (s?.pulsing ?? false) ? AppColors.accent : AppColors.accent700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(s?.text ?? '', style: AppTextStyles.meta)),
        ],
      ),
    );
  }
}
