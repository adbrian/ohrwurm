/// The Listen playback engine (APP_SPEC 11). Pure Dart: it plays clips through [ClipPlayer] and
/// never imports `just_audio` or Flutter, so it runs under a fake player in tests.
///
/// **Check the generation after every `await`. Never remove one.** An `await` doesn't block: while
/// this code waits for a clip or a pause, the user can swipe, and the swipe handler runs at once.
/// When the wait ends, the old code resumes and runs its next line, which may be an advance: two
/// advances from one swipe. `cancel()` can't stop code that is already running; it can only bump
/// the generation for that code to check when it wakes (APP_SPEC 11.3). The tests in
/// `test/playback/listen_engine_test.dart` fail if a check is removed or misplaced.
library;

import 'dart:async';

import '../data/models.dart';
import 'clip_player.dart';

export '../data/models.dart' show CardMode;

/// What a line is, which sets the pause after it (APP_SPEC 11.4).
enum LineRole { word, translation, germanSentence, englishSentence }

/// One line of a card's recipe: a clip, and what kind of line it is. The engine plays a card's
/// steps in order; the screen highlights the one at [ListenEngine.activeStep].
class Step {
  final String uri;
  final LineRole role;

  const Step(this.uri, this.role);

  @override
  String toString() => 'Step($uri, ${role.name})';
}

/// Pause lengths (APP_SPEC 11.4). They apply to the silence between clips, never to the clips:
/// speed is the player's business.
class Pauses {
  final Duration afterWord;
  final Duration afterTranslation;
  final Duration afterGermanSentence;
  final Duration afterEnglishSentence;
  final Duration betweenCards;

  const Pauses({
    this.afterWord = const Duration(milliseconds: 800),
    this.afterTranslation = const Duration(milliseconds: 1000),
    this.afterGermanSentence = const Duration(milliseconds: 1500),
    this.afterEnglishSentence = const Duration(milliseconds: 800),
    this.betweenCards = const Duration(milliseconds: 2000),
  });

  Duration after(LineRole role) => switch (role) {
    LineRole.word => afterWord,
    LineRole.translation => afterTranslation,
    LineRole.germanSentence => afterGermanSentence,
    LineRole.englishSentence => afterEnglishSentence,
  };
}

/// The session's cards as the engine sees them: a length, and each card's recipe and word key.
abstract class ListenDeck {
  int get length;

  /// The recipe's lines for the card at [index], in the order they play (APP_SPEC 9).
  List<Step> steps(int index);

  /// The word key the card counts towards when heard (APP_SPEC 7).
  String key(int index);
}

enum ListenPhase {
  /// Not playing: before [ListenEngine.start], or after [ListenEngine.stop].
  idle,

  /// A clip is playing: the line at [ListenEngine.activeStep].
  playing,

  /// The pause after a line.
  pause,

  /// The gap after a full pass, before the card repeats (looped) or the next card (continuous).
  gap,

  /// A clip couldn't be played. The card stops there, isn't counted as heard, and waits for a
  /// swipe or a replay (STATUS, 2026-09-24).
  failed,

  /// Past the last card: the end card (APP_SPEC 10.3). Nothing plays.
  end,
}

class ListenEngine {
  final ClipPlayer player;
  final ListenDeck deck;

  /// Read at each pause, so a change applies from the next one.
  Pauses pauses;

  /// Read at the end of each pass, so a change mid-card applies there (APP_SPEC 11.5).
  CardMode cardMode;

  /// A full pass of the card at this word key played to the end (APP_SPEC 7).
  final void Function(String key) onHeard;

  /// The position moved to this index; [ListenDeck.length] is the end card. The caller saves it
  /// (APP_SPEC 10.2).
  final void Function(int position) onAdvance;

  ListenEngine({
    required this.player,
    required this.deck,
    required this.pauses,
    required this.cardMode,
    required this.onHeard,
    required this.onAdvance,
    int position = 0,
  }) : _position = position; // ignore: prefer_initializing_formals

  int _position;

  /// The current card; [ListenDeck.length] is the end card.
  int get position => _position;

  bool get atEnd => _position >= deck.length;

  int? _activeStep;

  /// The line of the current card that is playing, or was last played; null before the first.
  int? get activeStep => _activeStep;

  ListenPhase _phase = ListenPhase.idle;
  ListenPhase get phase => _phase;

  /// During [ListenPhase.pause], the kind of line the pause follows.
  LineRole? get pausedAfter => _phase == ListenPhase.pause && _activeStep != null
      ? deck.steps(_position)[_activeStep!].role
      : null;

  /// The generation. Every [cancel] bumps it; code that was waiting checks it when it wakes and
  /// returns if it changed.
  int _gen = 0;
  Timer? _timer;
  Completer<void>? _sleeping;
  bool _disposed = false;

  final _listeners = <void Function()>[];

  /// Called whenever [position], [activeStep] or [phase] changes.
  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Plays the current card from its first line: at the start of a session, and on return from
  /// the background (APP_SPEC 11.5).
  void start() {
    if (_disposed) return;
    cancel();
    _playCardOrEnd(_gen);
  }

  /// Stops playback: the app went to the background, or the screen is closing. The card is not
  /// counted as heard; [start] plays it again from its first line.
  void stop() {
    cancel();
    _set(phase: atEnd ? ListenPhase.end : ListenPhase.idle);
  }

  /// Swipe (or **Next**): leave the card, however far it got (APP_SPEC 10.2).
  void swipe() {
    if (_disposed || atEnd) return;
    cancel();
    _advance(_gen);
  }

  /// Tap (or **Again**): the current card again from its first line. The position doesn't move.
  void replay() {
    if (_disposed || atEnd) return;
    cancel();
    _playCard(_position, _gen);
  }

  /// Everything waiting wakes to a new generation and returns without acting.
  void cancel() {
    _gen++;
    unawaited(player.stop());
    _timer?.cancel();
    _timer = null;
    final sleeping = _sleeping;
    _sleeping = null;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete();
  }

  void dispose() {
    stop();
    _disposed = true;
    _listeners.clear();
  }

  void _playCardOrEnd(int myGen) {
    if (atEnd) {
      _set(activeStep: null, phase: ListenPhase.end);
    } else {
      _playCard(_position, myGen);
    }
  }

  Future<void> _playCard(int index, int myGen) async {
    final steps = deck.steps(index);
    while (true) {
      for (var i = 0; i < steps.length; i++) {
        if (myGen != _gen) return;
        final step = steps[i];
        _set(activeStep: i, phase: ListenPhase.playing);
        final playing = player.play(step.uri);
        final next = i + 1 < steps.length ? steps[i + 1].uri : _firstClipAfter(index);
        if (next != null) player.preload(next);
        try {
          await playing;
        } catch (_) {
          if (myGen != _gen) return;
          _set(phase: ListenPhase.failed);
          return;
        }
        if (myGen != _gen) return;
        _set(phase: ListenPhase.pause);
        await _sleep(pauses.after(step.role));
        if (myGen != _gen) return;
      }
      // The full recipe played to the end (APP_SPEC 7).
      onHeard(deck.key(index));
      _set(phase: ListenPhase.gap);
      await _sleep(pauses.betweenCards);
      if (myGen != _gen) return;
      if (cardMode == CardMode.looped) continue;
      _advance(myGen);
      return;
    }
  }

  /// The clip that plays after the card at [index]: its own first line when looped, else the next
  /// card's.
  String? _firstClipAfter(int index) {
    final next = cardMode == CardMode.looped ? index : index + 1;
    if (next >= deck.length) return null;
    final steps = deck.steps(next);
    return steps.isEmpty ? null : steps.first.uri;
  }

  void _advance(int myGen) {
    _position++;
    _activeStep = null;
    onAdvance(_position);
    _playCardOrEnd(myGen);
  }

  Future<void> _sleep(Duration duration) {
    final done = Completer<void>();
    _sleeping = done;
    _timer = Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  void _set({Object? activeStep = _keep, ListenPhase? phase}) {
    if (!identical(activeStep, _keep)) _activeStep = activeStep as int?;
    if (phase != null) _phase = phase;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}

const _keep = Object();
