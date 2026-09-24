import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/data/pack_dao.dart';
import 'package:ohrwurm/packs/manifest.dart';
import 'package:ohrwurm/packs/pack_storage.dart';
import 'package:ohrwurm/packs/rescanner.dart';
import 'package:path/path.dart' as p;

import '../data/test_db.dart';
import 'directory_pack_storage.dart';

/// Rescan against a temporary copy of the fixture packs (APP_SPEC 15, step A2).
void main() {
  late FakeClock clock;
  late AppDatabase database;
  late Directory root;
  late DirectoryPackStorage storage;
  late Rescanner rescanner;

  setUp(() async {
    clock = FakeClock();
    database = await openTestDatabase(clock);
    root = copyFixturePacks();
    storage = DirectoryPackStorage();
    rescanner = Rescanner(storage: storage, packs: database.packs, schemaJson: schemaJson);
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  Future<RescanReport> rescan() async => (await rescanner.rescan(root.path)) as RescanReport;

  RescanRow row(RescanReport report, String folder) =>
      report.rows.singleWhere((r) => r.folderName == folder);

  String packDir(String packId) => p.join(root.path, packId);

  /// Rewrites a pack's `generated_at`, as the pipeline does when it regenerates a pack.
  void regenerate(String packId, String generatedAt) {
    final file = File(p.join(packDir(packId), 'manifest.json'));
    final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    manifest['generated_at'] = generatedAt;
    file.writeAsStringSync(jsonEncode(manifest));
  }

  test('valid packs load, a1_k03 is rejected whole, notes is skipped', () async {
    final report = await rescan();

    expect(row(report, 'a1_k02').outcome, RescanOutcome.added);
    expect(row(report, 'a1_k02').cardCount, 4);
    expect(row(report, 'a1_nb01').outcome, RescanOutcome.added);
    expect(row(report, 'a1_nb01').cardCount, 6);
    expect(row(report, 'notes').outcome, RescanOutcome.skipped);

    final k03 = row(report, 'a1_k03');
    expect(k03.outcome, RescanOutcome.rejected);
    expect((k03.rejection! as ClipsMissing).missing, ['a1_k03__die_stadt__ex1_src.ogg']);
    expect(k03.pack!.packId, 'a1_k03');
    expect(k03.known, isFalse);

    expect([for (final p in await database.packs.listPacks()) p.packId], ['a1_k02', 'a1_nb01']);
    expect(await database.cards.cardsInPack('a1_k03'), isEmpty);
    expect(
      [for (final c in await database.cards.cardsInPack('a1_k02')) c.key],
      ['der_freund', 'singen', 'heissen', 'gern'],
    );
    expect(report.changed, isTrue);
  });

  test('rows are in pack sort order, then non-packs by folder name', () async {
    Directory(p.join(root.path, 'aaa_misc')).createSync();
    final report = await rescan();
    expect(
      [for (final r in report.rows) r.folderName],
      ['a1_k02', 'a1_k03', 'a1_nb01', 'aaa_misc', 'notes'],
    );
  });

  test('lists the root and each subfolder exactly once', () async {
    await rescan();
    expect(storage.listed..sort(), [
      root.path,
      packDir('a1_k02'),
      packDir('a1_k03'),
      packDir('a1_nb01'),
      packDir('notes'),
    ]..sort());
  });

  test('a second rescan with nothing new reports unchanged', () async {
    Directory(packDir('a1_k03')).deleteSync(recursive: true);
    await rescan();
    clock.advance();

    final report = await rescan();
    expect(row(report, 'a1_k02').outcome, RescanOutcome.unchanged);
    expect(row(report, 'a1_k02').cardCount, 4);
    expect(row(report, 'a1_nb01').outcome, RescanOutcome.unchanged);
    expect(report.changed, isFalse);
  });

  test('a rejected pack is reported every time', () async {
    await rescan();
    final report = await rescan();
    expect(row(report, 'a1_k03').outcome, RescanOutcome.rejected);
    expect(report.changed, isTrue);
  });

  test('updating a pack replaces its cards and keeps progress', () async {
    await rescan();
    await database.progress.markHeard('der_freund');
    await database.progress.markHeard('singen');
    final before = (await database.packs.getPack('a1_k02'))!;

    regenerate('a1_k02', '2026-09-30T09:00:00Z');
    clock.advance(const Duration(days: 1));
    final report = await rescan();

    expect(row(report, 'a1_k02').outcome, RescanOutcome.updated);
    expect(row(report, 'a1_k02').known, isTrue);
    expect(row(report, 'a1_nb01').outcome, RescanOutcome.unchanged);
    final after = (await database.packs.getPack('a1_k02'))!;
    expect(after.generatedAt, '2026-09-30T09:00:00Z');
    expect(after.createdAt, before.createdAt);
    expect((await database.progress.get('der_freund'))!.timesHeard, 1);
    expect((await database.progress.get('singen'))!.timesHeard, 1);
  });

  test('a pack that disappears stays listed as unavailable, with its rows and progress',
      () async {
    await rescan();
    await database.progress.markHeard('gehen');
    Directory(packDir('a1_nb01')).deleteSync(recursive: true);

    final report = await rescan();
    final nb01 = row(report, 'a1_nb01');
    expect(nb01.outcome, RescanOutcome.notFound);
    expect(nb01.known, isTrue);
    expect(nb01.pack!.kind, 'notebook');
    expect(report.changed, isTrue);

    final packs = await database.packs.listPacks();
    expect([for (final p in packs) p.packId], ['a1_k02', 'a1_nb01']);
    expect(packs.last.available, isFalse);
    expect(await database.cards.cardsInPack('a1_nb01'), hasLength(6));
    expect((await database.progress.get('gehen'))!.timesHeard, 1);

    // Still missing: nothing new to report about it.
    final again = await rescan();
    expect(row(again, 'a1_nb01').outcome, RescanOutcome.notFound);
    expect(again.newlyUnavailable, isEmpty);
  });

  test('a pack that comes back unchanged is available again', () async {
    await rescan();
    final saved = Directory(packDir('a1_nb01')).renameSync(p.join(root.path, '..', 'nb01_away'));
    await rescan();
    saved.renameSync(packDir('a1_nb01'));

    final report = await rescan();
    expect(row(report, 'a1_nb01').outcome, RescanOutcome.unchanged);
    expect((await database.packs.getPack('a1_nb01'))!.available, isTrue);
  });

  test('a known pack whose folder loses its manifest is reported once, as not found', () async {
    await rescan();
    File(p.join(packDir('a1_nb01'), 'manifest.json')).deleteSync();

    final report = await rescan();
    expect(report.rows.where((r) => r.folderName == 'a1_nb01'), hasLength(1));
    expect(row(report, 'a1_nb01').outcome, RescanOutcome.notFound);
    expect((await database.packs.getPack('a1_nb01'))!.available, isFalse);
  });

  test('a known pack that fails its checks becomes unavailable and keeps its rows', () async {
    await rescan();
    await database.progress.markHeard('der_freund');
    File(p.join(packDir('a1_k02'), 'a1_k02__gern__word.ogg')).deleteSync();
    regenerate('a1_k02', '2026-09-30T09:00:00Z');

    final report = await rescan();
    final k02 = row(report, 'a1_k02');
    expect(k02.outcome, RescanOutcome.rejected);
    expect(k02.known, isTrue);
    expect((k02.rejection! as ClipsMissing).missing, ['a1_k02__gern__word.ogg']);
    expect(report.newlyUnavailable, {'a1_k02'});

    final pack = (await database.packs.getPack('a1_k02'))!;
    expect(pack.available, isFalse);
    expect(pack.generatedAt, '2026-09-23T14:30:00Z');
    expect(await database.cards.cardsInPack('a1_k02'), hasLength(4));
    expect((await database.progress.get('der_freund'))!.timesHeard, 1);
  });

  test('a manifest that is not JSON is rejected as unreadable', () async {
    File(p.join(packDir('a1_k02'), 'manifest.json')).writeAsStringSync('{"pack_id": ');
    final report = await rescan();
    expect(row(report, 'a1_k02').rejection, isA<ManifestUnreadable>());
    expect(row(report, 'a1_k02').pack, isNull);
  });

  test('a manifest that breaks the schema is rejected', () async {
    final file = File(p.join(packDir('a1_k02'), 'manifest.json'));
    final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    manifest['surprise'] = true;
    file.writeAsStringSync(jsonEncode(manifest));

    final report = await rescan();
    expect(row(report, 'a1_k02').rejection, isA<SchemaInvalid>());
    expect(await database.packs.getPack('a1_k02'), isNull);
  });

  test('a pack in a folder with another name is rejected', () async {
    Directory(packDir('a1_k02')).renameSync(packDir('a1_k05'));
    final report = await rescan();
    final k05 = row(report, 'a1_k05');
    expect((k05.rejection! as FolderMismatch).packId, 'a1_k02');
    expect(k05.pack, isNull);
    expect(await database.packs.getPack('a1_k02'), isNull);
  });

  test('a pack in an audio format this build cannot play is rejected', () async {
    final file = File(p.join(packDir('a1_k02'), 'manifest.json'));
    final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    manifest['audio_format'] = 'mp3';
    file.writeAsStringSync(jsonEncode(manifest));

    final report = await rescan();
    expect((row(report, 'a1_k02').rejection! as UnplayableAudio).format, 'mp3');
  });

  test('a pack that fails to save is rejected and the database is unchanged', () async {
    rescanner = Rescanner(
      storage: storage,
      packs: _FailingPackDao(database, failOn: 'a1_nb01'),
      schemaJson: schemaJson,
    );
    final report = await rescan();
    expect(row(report, 'a1_nb01').rejection, isA<SaveFailed>());
    expect(row(report, 'a1_k02').outcome, RescanOutcome.added);
    expect(await database.packs.getPack('a1_nb01'), isNull);
  });

  test('a missing root is reported and the database is not touched', () async {
    await rescan();
    final result = await rescanner.rescan(p.join(root.path, 'moved'));
    expect((result as RootUnavailable).access, RootAccess.missing);
    expect((await database.packs.getPack('a1_k02'))!.available, isTrue);
  });

  test('a root without permission is reported and the database is not touched', () async {
    await rescan();
    storage.access = RootAccess.denied;
    final result = await rescanner.rescan(root.path);
    expect((result as RootUnavailable).access, RootAccess.denied);
    expect((await database.packs.getPack('a1_nb01'))!.available, isTrue);
  });

  test('a pack folder picked as the root is recognised, and nothing is scanned', () async {
    final result = await rescanner.rescan(packDir('a1_k02'));
    expect(result, isA<RootIsAPack>());
    expect(await database.packs.listPacks(), isEmpty);
  });

  test('logs a timing line per folder and one for the whole rescan', () async {
    final lines = <String>[];
    rescanner = Rescanner(
      storage: storage,
      packs: database.packs,
      schemaJson: schemaJson,
      log: lines.add,
    );
    await rescan();
    expect(lines, hasLength(5));
    expect(lines.where((l) => l.startsWith('ohrwurm.rescan a1_k03 ')), hasLength(1));
    expect(lines.last, matches(RegExp(r'^ohrwurm\.rescan total \d+ ms: RescanReport$')));
  });

  test('an empty root reports nothing', () async {
    final empty = Directory(p.join(root.path, 'notes'));
    final report = (await rescanner.rescan(empty.path)) as RescanReport;
    expect(report.rows, isEmpty);
    expect(report.changed, isFalse);
  });
}

/// Fails `replacePack` for one pack, as a full disk would.
class _FailingPackDao extends PackDao {
  final String failOn;

  _FailingPackDao(AppDatabase database, {required this.failOn})
      : super(database.db, () => DateTime.utc(2026, 9, 24));

  @override
  Future<void> replacePack(PackInput pack, List<CardRow> cards) async {
    if (pack.packId == failOn) throw StateError('disk full');
    return super.replacePack(pack, cards);
  }
}
