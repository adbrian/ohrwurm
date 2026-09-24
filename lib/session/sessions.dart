import '../data/app_database.dart';
import '../data/models.dart';
import 'deck_builder.dart';
import 'session_cards.dart';

/// Creating, opening and restarting the saved session (APP_SPEC 10).
class Sessions {
  final AppDatabase db;
  final DeckBuilder deck;
  final ClipResolver clips;

  Sessions({required this.db, required this.deck, required this.clips});

  Future<Session?> saved() => db.session.load();

  /// Resolves the card order once, at creation, and saves it (APP_SPEC 10.1).
  Future<Session> create(SessionOptions options) async =>
      db.session.start(options, await deck.build(options));

  /// Loads the session's cards and their clips. When cards are gone (APP_SPEC 10.2) and the
  /// session goes on, the saved order drops them too, so the saved position keeps pointing into
  /// the order that's played.
  Future<OpenedSession> open(Session session) async {
    final opened = await openSession(session, cards: db.cards, packs: db.packs, clips: clips);
    if (opened.dropped > 0 && !opened.mostlyGone) {
      await db.session.setOrder([for (final c in opened.cards) c.row.cardId], opened.position);
    }
    await db.session.touch();
    return opened;
  }

  /// *Restart*: the same order from the first card (APP_SPEC 10.3).
  Future<Session> restart(Session session) async {
    await db.session.setOrder(session.cardOrder, 0);
    return (await db.session.load())!;
  }

  /// *Reshuffle*: a new order of the same cards, same options (APP_SPEC 10.3).
  Future<Session> reshuffle(Session session) async {
    await db.session.setOrder(deck.reshuffle(session.cardOrder), 0);
    return (await db.session.load())!;
  }

  Future<void> savePosition(int position) => db.session.setPosition(position);

  Future<void> saveCardMode(CardMode mode) => db.session.setCardMode(mode);
}
