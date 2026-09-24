import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'schema.dart';

/// Reads the `cards` table. Cards are written only with their pack, by `PackDao.replacePack`.
class CardDao {
  final Database _db;

  CardDao(this._db);

  /// A pack's cards in manifest order, optionally only those of [type] that have every example
  /// in [require].
  ///
  /// Manifest order is insertion order: `replacePack` inserts a pack's cards in manifest order,
  /// so `rowid` follows it.
  Future<List<CardRow>> cardsInPack(
    String packId, {
    String? type,
    Set<ExampleSlot> require = const {},
  }) async {
    final where = [
      'pack_id = ?',
      if (type != null) 'type = ?',
      for (final slot in require) '${slot.column} = 1',
    ];
    final rows = await _db.query(
      'cards',
      where: where.join(' AND '),
      whereArgs: [packId, ?type],
      orderBy: 'rowid',
    );
    return rows.map(CardRow.fromRow).toList();
  }

  Future<CardRow?> getCard(String cardId) async {
    final rows = await _db.query('cards', where: 'card_id = ?', whereArgs: [cardId]);
    return rows.isEmpty ? null : CardRow.fromRow(rows.single);
  }

  /// "Also in" (APP_SPEC 8): the other available packs containing [key], in pack sort order.
  Future<List<String>> alsoIn(String key, String packId) async {
    final rows = await _db.rawQuery('''
SELECT DISTINCT c.pack_id, p.level, p.kind, p.number
FROM cards c JOIN packs p ON p.pack_id = c.pack_id
WHERE c.key = ? AND c.pack_id != ? AND p.available = 1
ORDER BY ${packSortOrder('p')}''', [key, packId]);
    return [for (final row in rows) row['pack_id'] as String];
  }
}
