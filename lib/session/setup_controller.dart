import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/progress_dao.dart';
import '../library/library_controller.dart';
import 'deck_builder.dart';
import 'launch.dart';

/// Session setup (APP_SPEC 10.1, DESIGN 4): the packs chosen, in selection order, and the options,
/// with a live count of the cards they make. Also holds the saved session offered at launch
/// (APP_SPEC 10.2, DESIGN 3).
class SetupController extends ChangeNotifier {
  final LibraryController library;
  final DeckBuilder deck;
  final ProgressDao progress;

  SetupController({required this.library, required this.deck, required this.progress}) {
    library.addListener(_libraryChanged);
  }

  // The options, at APP_SPEC 10.1's defaults.
  SessionOptions _options = defaultOptions(const []);
  SessionOptions get options => _options;

  List<String> get selected => _options.packIds;
  bool isSelected(String packId) => selected.contains(packId);

  Map<String, PackProgress> _packProgress = const {};

  /// Heard / total distinct words per pack (APP_SPEC 7).
  PackProgress? packProgress(String packId) => _packProgress[packId];

  int? _count;

  /// The cards the current packs and options make, after *Unheard first* and the limit; null
  /// while it's being counted.
  int? get count => _count;

  int _countRequest = 0;

  Session? _resumeOffer;

  /// The saved session, offered once at launch before anything else (APP_SPEC 10.2).
  Session? get resumeOffer => _resumeOffer;

  void offerResume(Session? session) {
    _resumeOffer = session;
    // Trimmed to available packs once the library has loaded them.
    if (session != null) _options = session.options;
    notifyListeners();
  }

  /// The launch prompt is answered: Resume, New session, or Choose packs.
  void dismissResume() {
    _resumeOffer = null;
    notifyListeners();
    unawaited(refresh());
  }

  /// *Change selection* on the end card: setup with that session's packs and options.
  void prefill(SessionOptions o) {
    _options = _available(o);
    notifyListeners();
    unawaited(refresh());
  }

  void toggle(String packId) {
    final available = library.packs.any((p) => p.packId == packId && p.available);
    if (!available) return;
    final packs = isSelected(packId)
        ? [
            for (final id in selected)
              if (id != packId) id,
          ]
        : [...selected, packId];
    _set(packIds: packs);
  }

  void setMode(SessionMode v) => _set(mode: v);
  void setWords(Words v) => _set(words: v);
  void setFocus(WordFocus v) => _set(focus: v);
  void setStyle(Style v) => _set(style: v);
  void setQaTranslate(QaTranslate v) => _set(qaTranslate: v);
  void setDeckOrder(DeckOrder v) => _set(deckOrder: v);
  void setCardMode(CardMode v) => _set(cardMode: v);
  void setUnheardFirst(bool v) => _set(unheardFirst: v);

  /// The card-limit stepper's values: none, then 10 to 200.
  static const limitStep = 10;
  static const maxLimit = 200;

  void increaseLimit() {
    final limit = _options.cardLimit;
    if (limit != null && limit >= maxLimit) return;
    _set(cardLimit: (limit ?? 0) + limitStep);
  }

  void decreaseLimit() {
    final limit = _options.cardLimit;
    if (limit == null) return;
    _set(cardLimit: limit <= limitStep ? null : limit - limitStep, clearLimit: limit <= limitStep);
  }

  /// Reloads pack progress and the count: after a session, and whenever the library changes.
  Future<void> refresh() async {
    final progressNow = await progress.packProgress();
    _packProgress = progressNow;
    notifyListeners();
    await _recount();
  }

  void _set({
    List<String>? packIds,
    SessionMode? mode,
    Words? words,
    WordFocus? focus,
    Style? style,
    QaTranslate? qaTranslate,
    DeckOrder? deckOrder,
    CardMode? cardMode,
    int? cardLimit,
    bool clearLimit = false,
    bool? unheardFirst,
  }) {
    final o = _options;
    _options = SessionOptions(
      mode: mode ?? o.mode,
      packIds: packIds ?? o.packIds,
      words: words ?? o.words,
      focus: focus ?? o.focus,
      style: style ?? o.style,
      qaTranslate: qaTranslate ?? o.qaTranslate,
      deckOrder: deckOrder ?? o.deckOrder,
      cardMode: cardMode ?? o.cardMode,
      cardLimit: clearLimit ? null : cardLimit ?? o.cardLimit,
      unheardFirst: unheardFirst ?? o.unheardFirst,
    );
    notifyListeners();
    unawaited(_recount());
  }

  Future<void> _recount() async {
    final request = ++_countRequest;
    if (selected.isEmpty) {
      _count = 0;
      notifyListeners();
      return;
    }
    _count = null;
    notifyListeners();
    final order = await deck.build(_options);
    // A later change started another count.
    if (request != _countRequest) return;
    _count = order.length;
    notifyListeners();
  }

  /// Unavailable packs can't be chosen: they're dropped from the selection.
  SessionOptions _available(SessionOptions o) {
    final available = {
      for (final p in library.packs)
        if (p.available) p.packId,
    };
    return SessionOptions(
      mode: o.mode,
      packIds: [
        for (final id in o.packIds)
          if (available.contains(id)) id,
      ],
      words: o.words,
      focus: o.focus,
      style: o.style,
      qaTranslate: o.qaTranslate,
      deckOrder: o.deckOrder,
      cardMode: o.cardMode,
      cardLimit: o.cardLimit,
      unheardFirst: o.unheardFirst,
    );
  }

  List<Pack> _lastPacks = const [];

  void _libraryChanged() {
    if (identical(library.packs, _lastPacks)) return;
    _lastPacks = library.packs;
    // Nothing loaded yet: keep the selection until the packs are known.
    if (library.packs.isEmpty) return;
    final trimmed = _available(_options);
    if (trimmed.packIds.length != _options.packIds.length) _options = trimmed;
    unawaited(refresh());
  }

  @override
  void dispose() {
    library.removeListener(_libraryChanged);
    super.dispose();
  }
}
