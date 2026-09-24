import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'clock.dart';
import 'models.dart';

/// The single `session` row (APP_SPEC 6, 10.2).
class SessionDao {
  final Database _db;
  final Clock _clock;

  SessionDao(this._db, this._clock);

  /// Starts a new session at position 0, replacing any existing one. [cardOrder] is the resolved
  /// order: resuming replays it exactly, even if packs change.
  Future<Session> start(SessionOptions options, List<String> cardOrder) async {
    final now = timestamp(_clock);
    await _db.insert('session', {
      'id': 1,
      'mode': options.mode.name,
      'pack_ids_json': jsonEncode(options.packIds),
      'words': options.words.name,
      'focus': options.focus.name,
      'style': options.style.name,
      'qa_translate': options.qaTranslate.name,
      'deck_order': options.deckOrder.name,
      'card_mode': options.cardMode.name,
      'card_limit': options.cardLimit,
      'unheard_first': options.unheardFirst ? 1 : 0,
      'card_order_json': jsonEncode(cardOrder),
      'position': 0,
      'created_at': now,
      'last_opened_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return Session(
      options: options,
      cardOrder: List.unmodifiable(cardOrder),
      position: 0,
      createdAt: now,
      lastOpenedAt: now,
    );
  }

  Future<Session?> load() async {
    final rows = await _db.query('session', where: 'id = 1');
    if (rows.isEmpty) return null;
    final row = rows.single;
    return Session(
      options: SessionOptions(
        mode: SessionMode.values.byName(row['mode'] as String),
        packIds: _stringList(row['pack_ids_json']),
        words: Words.values.byName(row['words'] as String),
        focus: WordFocus.values.byName(row['focus'] as String),
        style: Style.values.byName(row['style'] as String),
        qaTranslate: QaTranslate.values.byName(row['qa_translate'] as String),
        deckOrder: DeckOrder.values.byName(row['deck_order'] as String),
        cardMode: CardMode.values.byName(row['card_mode'] as String),
        cardLimit: row['card_limit'] as int?,
        unheardFirst: row['unheard_first'] == 1,
      ),
      cardOrder: _stringList(row['card_order_json']),
      position: row['position'] as int,
      createdAt: row['created_at'] as String,
      lastOpenedAt: row['last_opened_at'] as String,
    );
  }

  /// Written on every advance (APP_SPEC 10.2).
  Future<void> setPosition(int position) async {
    await _db.update('session', {'position': position}, where: 'id = 1');
  }

  /// Loop or continuous, changed from the Listen card (APP_SPEC 11.5).
  Future<void> setCardMode(CardMode mode) async {
    await _db.update('session', {'card_mode': mode.name}, where: 'id = 1');
  }

  /// Replaces the card order and the position: *Restart* and *Reshuffle* (APP_SPEC 10.3), and
  /// dropping cards that are gone on resume (APP_SPEC 10.2).
  Future<void> setOrder(List<String> cardOrder, int position) async {
    await _db.update('session', {
      'card_order_json': jsonEncode(cardOrder),
      'position': position,
    }, where: 'id = 1');
  }

  /// The session was opened (resumed).
  Future<void> touch() async {
    await _db.update('session', {'last_opened_at': timestamp(_clock)}, where: 'id = 1');
  }

  Future<void> clear() async {
    await _db.delete('session');
  }

  static List<String> _stringList(Object? json) =>
      List.unmodifiable((jsonDecode(json as String) as List).cast<String>());
}
