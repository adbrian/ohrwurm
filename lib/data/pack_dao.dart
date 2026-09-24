import 'package:sqflite/sqflite.dart';

import 'clock.dart';
import 'models.dart';
import 'schema.dart';

/// The `packs` table, and writing a pack together with its cards.
///
/// Nothing here touches `progress` (APP_SPEC 5.2, step 5).
class PackDao {
  final Database _db;
  final Clock _clock;

  PackDao(this._db, this._clock);

  /// All packs, available or not, in the APP_SPEC 4.3 sort order.
  Future<List<Pack>> listPacks() async {
    final rows = await _db.query('packs', orderBy: packSortOrder());
    return rows.map(Pack.fromRow).toList();
  }

  Future<Pack?> getPack(String packId) async {
    final rows = await _db.query('packs', where: 'pack_id = ?', whereArgs: [packId]);
    return rows.isEmpty ? null : Pack.fromRow(rows.single);
  }

  /// Writes [pack] and replaces all of its cards with [cards], in manifest order, in a single
  /// transaction: if anything fails, the pack is left exactly as it was (APP_SPEC 5.2).
  ///
  /// A new pack gets `created_at` now; a known pack keeps its `created_at`. Either way the pack
  /// is marked available.
  Future<void> replacePack(PackInput pack, List<CardRow> cards) async {
    for (final card in cards) {
      if (card.packId != pack.packId) {
        throw ArgumentError('Card ${card.cardId} belongs to ${card.packId}, not ${pack.packId}');
      }
    }
    final fields = {
      'level': pack.level,
      'kind': pack.kind,
      'number': pack.number,
      'title': pack.title,
      'card_count': cards.length,
      'audio_format': pack.audioFormat,
      'available': 1,
      'generated_at': pack.generatedAt,
    };
    await _db.transaction((txn) async {
      // No upsert: Android 10's SQLite predates it (see schema.dart).
      final updated = await txn.update(
        'packs',
        fields,
        where: 'pack_id = ?',
        whereArgs: [pack.packId],
      );
      if (updated == 0) {
        await txn.insert('packs', {
          'pack_id': pack.packId,
          ...fields,
          'created_at': timestamp(_clock),
        });
      }
      await txn.delete('cards', where: 'pack_id = ?', whereArgs: [pack.packId]);
      final batch = txn.batch();
      for (final card in cards) {
        batch.insert('cards', card.toRow());
      }
      await batch.commit(noResult: true);
    });
  }

  /// Marks a pack found or not found on disk. Its rows are kept either way.
  Future<void> setAvailable(String packId, bool available) async {
    await _db.update(
      'packs',
      {'available': available ? 1 : 0},
      where: 'pack_id = ?',
      whereArgs: [packId],
    );
  }
}
