import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/card_dao.dart';
import '../data/models.dart';
import '../data/progress_dao.dart';
import '../playback/clip_player.dart';
import '../playback/listen_engine.dart';
import 'deck_builder.dart';
import 'session_cards.dart';
import 'sessions.dart';

/// A Listen session on screen: the engine, the session it plays, and what it writes back —
/// position on every advance (APP_SPEC 10.2) and a word heard on every full pass (APP_SPEC 7).
class ListenController extends ChangeNotifier {
  final Sessions sessions;
  final ProgressDao progress;
  final CardDao cardDao;
  final ClipPlayer player;
  final Pauses pauses;

  ListenController({
    required OpenedSession opened,
    required this.sessions,
    required this.progress,
    required this.cardDao,
    required this.player,
    required this.pauses,
  }) {
    _load(opened);
  }

  late OpenedSession _opened;
  late ListenCards _deck;
  late ListenEngine _engine;

  Session get session => _opened.session;
  ListenCards get deck => _deck;
  ListenEngine get engine => _engine;
  int get position => _engine.position;
  int get length => _deck.length;
  bool get atEnd => _engine.atEnd;
  CardMode get cardMode => _engine.cardMode;

  /// The current card, or null on the end card.
  SessionCard? get card => atEnd ? null : _deck.cards[position];

  bool _replaying = false;
  Timer? _replayTimer;

  /// *Replaying…* shows for about a second after a replay (DESIGN 6).
  bool get replaying => _replaying;

  bool _stopped = false;
  bool _disposed = false;

  final Map<int, List<String>> _alsoIn = {};

  /// "Also in" for the current card: the other available packs with its word key (APP_SPEC 8).
  /// Computed when the card is shown, never stored.
  List<String> get alsoIn => _alsoIn[position] ?? const [];

  void _load(OpenedSession opened) {
    _opened = opened;
    final options = opened.session.options;
    _deck = ListenCards(opened.cards, recipeFor(options), options.qaTranslate);
    _engine = ListenEngine(
      player: player,
      deck: _deck,
      pauses: pauses,
      cardMode: options.cardMode,
      position: opened.position,
      onHeard: (key) => unawaited(progress.markHeard(key)),
      onAdvance: (position) {
        unawaited(sessions.savePosition(position));
        _loadAlsoIn(position);
      },
    )..addListener(_changed);
    _alsoIn.clear();
    _loadAlsoIn(opened.position);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadAlsoIn(int index) async {
    if (index >= _deck.length || _alsoIn.containsKey(index)) return;
    final row = _deck.cards[index].row;
    final packs = await cardDao.alsoIn(row.key, row.packId);
    if (_disposed) return;
    _alsoIn[index] = packs;
    if (index == position) notifyListeners();
  }

  /// Plays the current card from its first line.
  void start() {
    _stopped = false;
    _engine.start();
  }

  /// The app went to the background, a call came in, or the screen is closing. Nothing is lost:
  /// the position is saved, and [start] restarts the card (APP_SPEC 11.5).
  void stop() {
    _stopped = true;
    _engine.stop();
  }

  bool get stopped => _stopped;

  void swipe() => _engine.swipe();

  void replay() {
    if (atEnd) return;
    _engine.replay();
    _replaying = true;
    _replayTimer?.cancel();
    _replayTimer = Timer(const Duration(seconds: 1), () {
      _replaying = false;
      _changed();
    });
    notifyListeners();
  }

  /// The *Loop* pill. Takes effect at the end of the current pass (APP_SPEC 11.5), and is saved
  /// with the session.
  void toggleLoop() {
    final mode = cardMode == CardMode.looped ? CardMode.continuous : CardMode.looped;
    _engine.cardMode = mode;
    unawaited(sessions.saveCardMode(mode));
    notifyListeners();
  }

  /// *Restart* on the end card: the same order from the first card (APP_SPEC 10.3).
  Future<void> restart() => _replace(sessions.restart);

  /// *Reshuffle* on the end card: a new order of the same cards (APP_SPEC 10.3).
  Future<void> reshuffle() => _replace(sessions.reshuffle);

  Future<void> _replace(Future<Session> Function(Session) change) async {
    _engine.dispose();
    final updated = await change(session);
    final byId = {for (final c in _opened.cards) c.row.cardId: c};
    final cards = [
      for (final id in updated.cardOrder)
        if (byId[id] != null) byId[id]!,
    ];
    final mode = _engine.cardMode;
    if (_disposed) return;
    _load(
      OpenedSession(
        session: Session(
          options: _withCardMode(updated.options, mode),
          cardOrder: updated.cardOrder,
          position: 0,
          createdAt: updated.createdAt,
          lastOpenedAt: updated.lastOpenedAt,
        ),
        cards: cards,
        position: 0,
        dropped: 0,
      ),
    );
    notifyListeners();
    if (!_stopped) _engine.start();
  }

  static SessionOptions _withCardMode(SessionOptions o, CardMode mode) => SessionOptions(
    mode: o.mode,
    packIds: o.packIds,
    words: o.words,
    focus: o.focus,
    style: o.style,
    qaTranslate: o.qaTranslate,
    deckOrder: o.deckOrder,
    cardMode: mode,
    cardLimit: o.cardLimit,
    unheardFirst: o.unheardFirst,
  );

  @override
  void dispose() {
    _disposed = true;
    _replayTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }
}
