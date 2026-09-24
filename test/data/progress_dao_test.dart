import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';

import 'test_db.dart';

void main() {
  late FakeClock clock;
  late AppDatabase database;

  setUp(() async {
    clock = FakeClock();
    database = await openTestDatabase(clock);
  });

  tearDown(() => database.close());

  test('markHeard counts each hearing and keeps the first time', () async {
    expect(await database.progress.get('der_freund'), isNull);

    await database.progress.markHeard('der_freund');
    var progress = (await database.progress.get('der_freund'))!;
    expect(progress.timesHeard, 1);
    expect(progress.firstHeardAt, '2026-09-24T08:00:00.000Z');
    expect(progress.lastHeardAt, '2026-09-24T08:00:00.000Z');
    expect(progress.timesRecorded, 0);

    clock.advance();
    await database.progress.markHeard('der_freund');
    progress = (await database.progress.get('der_freund'))!;
    expect(progress.timesHeard, 2);
    expect(progress.firstHeardAt, '2026-09-24T08:00:00.000Z');
    expect(progress.lastHeardAt, '2026-09-24T08:01:00.000Z');
  });

  test('incrementRecorded counts recordings without marking the word heard', () async {
    await database.progress.incrementRecorded('der_freund');
    await database.progress.incrementRecorded('der_freund');

    final progress = (await database.progress.get('der_freund'))!;
    expect(progress.timesRecorded, 2);
    expect(progress.timesHeard, 0);
    expect(progress.firstHeardAt, isNull);
    expect(progress.lastHeardAt, isNull);
  });

  group('packProgress', () {
    setUp(() async {
      await database.packs.replacePack(packInput('a1_k02'), [
        card('a1_k02', 'der_freund'),
        card('a1_k02', 'singen', type: 'verb'),
        card('a1_k02', 'gehen', type: 'verb'),
      ]);
      await database.packs.replacePack(packInput('a1_nb01'), [
        card('a1_nb01', 'der_freund'),
        card('a1_nb01', 'gehen', type: 'verb'),
        card('a1_nb01', 'gehen_2', type: 'verb'),
        card('a1_nb01', 'die_leute'),
      ]);
    });

    test('starts at nothing heard', () async {
      expect(await database.progress.packProgress(), {
        'a1_k02': const PackProgress(heard: 0, total: 3),
        'a1_nb01': const PackProgress(heard: 0, total: 4),
      });
    });

    test('hearing der_freund in a1_k02 counts in a1_nb01', () async {
      await database.progress.markHeard('der_freund');
      expect(await database.progress.packProgress(), {
        'a1_k02': const PackProgress(heard: 1, total: 3),
        'a1_nb01': const PackProgress(heard: 1, total: 4),
      });
    });

    test('gehen and gehen_2 are tracked separately', () async {
      await database.progress.markHeard('gehen_2');
      expect(await database.progress.packProgress(), {
        'a1_k02': const PackProgress(heard: 0, total: 3),
        'a1_nb01': const PackProgress(heard: 1, total: 4),
      });
    });

    test('a word heard twice counts once; a recording alone does not count', () async {
      await database.progress.markHeard('singen');
      await database.progress.markHeard('singen');
      await database.progress.incrementRecorded('der_freund');
      expect(
        (await database.progress.packProgress())['a1_k02'],
        const PackProgress(heard: 1, total: 3),
      );
    });

    test('progress for keys in no pack is kept and ignored', () async {
      await database.progress.markHeard('verschwunden');
      expect(
        (await database.progress.packProgress())['a1_k02'],
        const PackProgress(heard: 0, total: 3),
      );
      expect((await database.progress.get('verschwunden'))!.timesHeard, 1);
    });
  });
}
