import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'card_dao.dart';
import 'clock.dart';
import 'pack_dao.dart';
import 'progress_dao.dart';
import 'schema.dart';
import 'session_dao.dart';

/// Migrations to reach each version from the one before. To change the schema: add an entry
/// for the next version and bump [AppDatabase.version]. Never edit [schemaV1] — installed
/// databases already have it. No migration may delete `progress` rows.
const Map<int, Future<void> Function(DatabaseExecutor db)> migrations = {};

class AppDatabase {
  static const version = 1;
  static const fileName = 'ohrwurm.db';

  final Database db;
  final PackDao packs;
  final CardDao cards;
  final ProgressDao progress;
  final SessionDao session;

  AppDatabase._(this.db, Clock clock)
    : packs = PackDao(db, clock),
      cards = CardDao(db),
      progress = ProgressDao(db, clock),
      session = SessionDao(db, clock);

  /// Opens the database, creating the schema on first launch.
  ///
  /// Tests pass [factory] (`sqflite_common_ffi`) and [path] (`inMemoryDatabasePath`).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
    Clock clock = systemClock,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, newVersion) async {
          final batch = db.batch();
          for (final statement in schemaV1) {
            batch.execute(statement);
          }
          await batch.commit(noResult: true);
          await _migrate(db, 1, newVersion);
        },
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase._(db, clock);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      final migration = migrations[v];
      if (migration == null) throw StateError('No migration to database version $v');
      await migration(db);
    }
  }

  Future<void> close() => db.close();
}
