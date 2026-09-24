import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_db.dart';

void main() {
  late FakeClock clock;
  late AppDatabase database;

  setUp(() async {
    clock = FakeClock();
    database = await openTestDatabase(clock);
  });

  tearDown(() => database.close());

  Future<List<String>> columns(String table) async {
    final rows = await database.db.rawQuery('PRAGMA table_info($table)');
    return [for (final row in rows) row['name'] as String];
  }

  test('creates the APP_SPEC 6 tables and indexes', () async {
    final rows = await database.db.rawQuery(
      "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    expect(
      [for (final row in rows) '${row['type']} ${row['name']}'],
      [
        'table cards',
        'index idx_cards_key',
        'index idx_cards_pack',
        'table packs',
        'table progress',
        'table session',
      ],
    );
  });

  test('tables have the APP_SPEC 6 columns', () async {
    expect(await columns('packs'), [
      'pack_id', 'level', 'kind', 'number', 'title', 'card_count', 'audio_format', //
      'available', 'created_at', 'generated_at',
    ]);
    expect(await columns('cards'), [
      'card_id', 'pack_id', 'key', 'type', 'added_at', //
      'has_base_statement', 'has_base_qa', 'has_plural_statement', 'has_plural_qa',
      'has_feminine_statement', 'has_feminine_qa', 'content_json',
    ]);
    expect(await columns('progress'), [
      'key', 'times_heard', 'first_heard_at', 'last_heard_at', 'times_recorded', //
    ]);
    expect(await columns('session'), [
      'id', 'mode', 'pack_ids_json', 'words', 'focus', 'style', 'qa_translate', //
      'deck_order', 'card_mode', 'card_limit', 'unheard_first', 'card_order_json', 'position',
      'created_at', 'last_opened_at',
    ]);
  });

  test('no table has a foreign key, so nothing can cascade into progress', () async {
    for (final table in ['packs', 'cards', 'progress', 'session']) {
      expect(await database.db.rawQuery('PRAGMA foreign_key_list($table)'), isEmpty, reason: table);
    }
  });

  test('database is at version ${AppDatabase.version}', () async {
    expect(await database.db.getVersion(), AppDatabase.version);
  });

  test('session holds at most one row', () async {
    expect(
      () => database.db.rawInsert('''
INSERT INTO session (id, mode, pack_ids_json, words, focus, style, qa_translate, deck_order,
  card_mode, unheard_first, card_order_json, created_at, last_opened_at)
VALUES (2, 'listen', '[]', 'all', 'base', 'statement', 'both', 'sequential', 'looped', 0, '[]',
  'x', 'x')'''),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('reopening an existing database keeps its data', () async {
    final dir = await Directory.systemTemp.createTemp('ohrwurm_schema_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, AppDatabase.fileName);

    final first = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: clock.call,
    );
    await first.progress.markHeard('der_freund');
    await first.close();

    final second = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
      clock: clock.call,
    );
    addTearDown(second.close);
    expect((await second.progress.get('der_freund'))!.timesHeard, 1);
  });
}
