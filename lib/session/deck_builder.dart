import 'dart:math';

import '../cards/recipe.dart';
import '../data/card_dao.dart';
import '../data/models.dart';
import '../data/progress_dao.dart';

/// Whether Focus applies to these options. It's offered only when Words is *all* or *nouns*
/// (APP_SPEC 9), and only in Listen: Mirror's boxes are always base examples (APP_SPEC 12;
/// STATUS, 2026-09-24).
bool focusApplies(SessionOptions o) =>
    o.mode == SessionMode.listen && (o.words == Words.all || o.words == Words.noun);

/// The focus these options actually use.
WordFocus effectiveFocus(SessionOptions o) => focusApplies(o) ? o.focus : WordFocus.base;

/// The Listen recipe for these options (APP_SPEC 9).
Recipe recipeFor(SessionOptions o) => Recipe.of(effectiveFocus(o), o.style);

/// The examples a card needs to be in the session. Cards lacking one are excluded (APP_SPEC 9,
/// 12).
Set<ExampleSlot> requiredSlots(SessionOptions o) => switch (o.mode) {
  SessionMode.listen => recipeFor(o).requires,
  SessionMode.mirror => {
    o.style == Style.statement ? ExampleSlot.baseStatement : ExampleSlot.baseQa,
  },
};

/// The card `type` these options admit, or null for all. Plural and feminine focus only ever
/// match nouns (APP_SPEC 9).
String? typeFilter(SessionOptions o) => switch (o.words) {
  Words.all => effectiveFocus(o) == WordFocus.base ? null : 'noun',
  Words.noun => 'noun',
  Words.verb => 'verb',
  Words.other => 'other',
};

/// Resolves a session's card order from its options (APP_SPEC 10.1). The order is saved with the
/// session and never recomputed mid-session.
class DeckBuilder {
  final CardDao cards;
  final ProgressDao progress;
  final Random random;

  DeckBuilder({required this.cards, required this.progress, Random? random})
    : random = random ?? Random();

  /// The cards these options admit, before order, *Unheard first* and the limit: in pack
  /// selection order, each pack's cards in manifest order.
  Future<List<CardRow>> matching(SessionOptions o) async {
    final type = typeFilter(o);
    final require = requiredSlots(o);
    return [
      for (final packId in o.packIds)
        ...await cards.cardsInPack(packId, type: type, require: require),
    ];
  }

  /// The resolved order of card ids.
  Future<List<String>> build(SessionOptions o) async {
    var deck = await matching(o);
    if (o.deckOrder == DeckOrder.shuffled) deck.shuffle(random);
    if (o.unheardFirst) {
      final heard = await progress.heardKeys();
      // Stable: the deck order is kept within each group.
      deck = [
        ...deck.where((c) => !heard.contains(c.key)),
        ...deck.where((c) => heard.contains(c.key)),
      ];
    }
    final limit = o.cardLimit;
    if (limit != null && deck.length > limit) deck = deck.sublist(0, limit);
    return [for (final c in deck) c.cardId];
  }

  /// *Reshuffle* on the end card: a new order of the same cards (APP_SPEC 10.3).
  List<String> reshuffle(List<String> order) => List.of(order)..shuffle(random);
}
