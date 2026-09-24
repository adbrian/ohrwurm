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

  Future<List<String>> keysIn(String packId) async =>
      [for (final c in await database.cards.cardsInPack(packId)) c.key];

  test('replacePack inserts a new pack and its cards', () async {
    await database.packs.replacePack(
      packInput('a1_k02', title: 'Freunde'),
      [card('a1_k02', 'der_freund'), card('a1_k02', 'singen', type: 'verb')],
    );

    final pack = (await database.packs.getPack('a1_k02'))!;
    expect(pack.level, 'a1');
    expect(pack.kind, 'textbook');
    expect(pack.number, 2);
    expect(pack.title, 'Freunde');
    expect(pack.cardCount, 2);
    expect(pack.audioFormat, 'opus');
    expect(pack.available, isTrue);
    expect(pack.createdAt, '2026-09-24T08:00:00.000Z');
    expect(pack.generatedAt, '2026-09-01T10:00:00Z');
    expect(await keysIn('a1_k02'), ['der_freund', 'singen']);
  });

  test('replacePack on a known pack replaces its cards wholesale and keeps created_at', () async {
    await database.packs.replacePack(
      packInput('a1_k02'),
      [card('a1_k02', 'der_freund'), card('a1_k02', 'singen')],
    );
    clock.advance(const Duration(days: 3));
    await database.packs.replacePack(
      packInput('a1_k02', generatedAt: '2026-09-20T10:00:00Z', title: 'Neu'),
      [card('a1_k02', 'die_freundin')],
    );

    final pack = (await database.packs.getPack('a1_k02'))!;
    expect(pack.createdAt, '2026-09-24T08:00:00.000Z');
    expect(pack.generatedAt, '2026-09-20T10:00:00Z');
    expect(pack.title, 'Neu');
    expect(pack.cardCount, 1);
    expect(await keysIn('a1_k02'), ['die_freundin']);
  });

  test('replacePack leaves other packs alone', () async {
    await database.packs.replacePack(packInput('a1_k02'), [card('a1_k02', 'der_freund')]);
    await database.packs.replacePack(packInput('a1_nb01'), [card('a1_nb01', 'der_freund')]);
    await database.packs.replacePack(packInput('a1_k02'), [card('a1_k02', 'singen')]);

    expect(await keysIn('a1_nb01'), ['der_freund']);
  });

  test('a failed replacePack leaves the pack exactly as it was', () async {
    await database.packs.replacePack(packInput('a1_k02'), [card('a1_k02', 'der_freund')]);

    // Two cards with the same card_id: the second insert violates the primary key.
    await expectLater(
      database.packs.replacePack(
        packInput('a1_k02', generatedAt: '2026-09-20T10:00:00Z'),
        [card('a1_k02', 'singen'), card('a1_k02', 'singen')],
      ),
      throwsA(anything),
    );

    final pack = (await database.packs.getPack('a1_k02'))!;
    expect(pack.generatedAt, '2026-09-01T10:00:00Z');
    expect(pack.cardCount, 1);
    expect(await keysIn('a1_k02'), ['der_freund']);
  });

  test('a failed replacePack of a new pack writes nothing', () async {
    await expectLater(
      database.packs.replacePack(
        packInput('a1_k02'),
        [card('a1_k02', 'singen'), card('a1_k02', 'singen')],
      ),
      throwsA(anything),
    );
    expect(await database.packs.getPack('a1_k02'), isNull);
    expect(await keysIn('a1_k02'), isEmpty);
  });

  test('replacePack rejects a card from another pack', () async {
    expect(
      () => database.packs.replacePack(packInput('a1_k02'), [card('a1_nb01', 'der_freund')]),
      throwsArgumentError,
    );
  });

  test('listPacks sorts by level, then textbook before notebook, then number', () async {
    for (final id in ['b1_k01', 'a1_nb01', 'a1_k10', 'a2_k01', 'a1_k02', 'a1_nb02']) {
      await database.packs.replacePack(packInput(id), [card(id, 'x')]);
    }
    expect(
      [for (final p in await database.packs.listPacks()) p.packId],
      ['a1_k02', 'a1_k10', 'a1_nb01', 'a1_nb02', 'a2_k01', 'b1_k01'],
    );
  });

  test('an unavailable pack keeps its rows and is still listed', () async {
    await database.packs.replacePack(packInput('a1_k02'), [card('a1_k02', 'der_freund')]);
    await database.packs.setAvailable('a1_k02', false);

    final packs = await database.packs.listPacks();
    expect(packs.single.packId, 'a1_k02');
    expect(packs.single.available, isFalse);
    expect(await keysIn('a1_k02'), ['der_freund']);

    await database.packs.setAvailable('a1_k02', true);
    expect((await database.packs.getPack('a1_k02'))!.available, isTrue);
  });

  test('replacePack marks an unavailable pack available again', () async {
    await database.packs.replacePack(packInput('a1_k02'), [card('a1_k02', 'der_freund')]);
    await database.packs.setAvailable('a1_k02', false);
    await database.packs.replacePack(packInput('a1_k02'), [card('a1_k02', 'der_freund')]);

    expect((await database.packs.getPack('a1_k02'))!.available, isTrue);
  });

  test('progress survives replacing and losing a pack', () async {
    await database.packs.replacePack(packInput('a1_k02'), [card('a1_k02', 'der_freund')]);
    await database.progress.markHeard('der_freund');
    await database.progress.incrementRecorded('der_freund');

    // The word leaves the pack, then the pack disappears altogether.
    await database.packs.replacePack(
      packInput('a1_k02', generatedAt: '2026-09-20T10:00:00Z'),
      [card('a1_k02', 'singen')],
    );
    await database.packs.setAvailable('a1_k02', false);

    final progress = (await database.progress.get('der_freund'))!;
    expect(progress.timesHeard, 1);
    expect(progress.timesRecorded, 1);

    // The word comes back: its progress reattaches.
    await database.packs.replacePack(
      packInput('a1_k02', generatedAt: '2026-09-21T10:00:00Z'),
      [card('a1_k02', 'der_freund')],
    );
    expect(
      (await database.progress.packProgress())['a1_k02'],
      const PackProgress(heard: 1, total: 1),
    );
  });
}
