import 'package:sqflite/sqflite.dart';

import 'clock.dart';
import 'models.dart';

/// The `progress` table, keyed by word key and shared across packs (APP_SPEC 7).
///
/// There is deliberately no way to delete progress (CLAUDE.md, rule 5).
class ProgressDao {
  final Database _db;
  final Clock _clock;

  ProgressDao(this._db, this._clock);

  /// A card's full recipe played to the end.
  Future<void> markHeard(String key) async {
    final now = timestamp(_clock);
    await _db.transaction((txn) async {
      await txn.rawInsert('INSERT OR IGNORE INTO progress (key) VALUES (?)', [key]);
      await txn.rawUpdate('''
UPDATE progress
SET times_heard = times_heard + 1,
    first_heard_at = COALESCE(first_heard_at, ?),
    last_heard_at = ?
WHERE key = ?''', [now, now, key]);
    });
  }

  /// A Mirror recording finished.
  Future<void> incrementRecorded(String key) async {
    await _db.transaction((txn) async {
      await txn.rawInsert('INSERT OR IGNORE INTO progress (key) VALUES (?)', [key]);
      await txn.rawUpdate(
        'UPDATE progress SET times_recorded = times_recorded + 1 WHERE key = ?',
        [key],
      );
    });
  }

  Future<Progress?> get(String key) async {
    final rows = await _db.query('progress', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : Progress.fromRow(rows.single);
  }

  /// Pack progress for every pack that has cards: its distinct keys heard at least once, and
  /// its distinct keys.
  Future<Map<String, PackProgress>> packProgress() async {
    final rows = await _db.rawQuery('''
SELECT c.pack_id,
       COUNT(DISTINCT c.key) AS total,
       COUNT(DISTINCT CASE WHEN p.times_heard > 0 THEN c.key END) AS heard
FROM cards c LEFT JOIN progress p ON p.key = c.key
GROUP BY c.pack_id''');
    return {
      for (final row in rows)
        row['pack_id'] as String: PackProgress(
          heard: row['heard'] as int,
          total: row['total'] as int,
        ),
    };
  }
}
