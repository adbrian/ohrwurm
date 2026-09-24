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

  test('cardsInPack returns cards in manifest order, not key order', () async {
    await database.packs.replacePack(packInput('a1_k02'), [
      card('a1_k02', 'singen'),
      card('a1_k02', 'der_arzt'),
      card('a1_k02', 'mit'),
    ]);
    expect(
      [for (final c in await database.cards.cardsInPack('a1_k02')) c.key],
      ['singen', 'der_arzt', 'mit'],
    );
  });

  test('cardsInPack filters by type and required examples', () async {
    await database.packs.replacePack(packInput('a1_k02'), [
      card('a1_k02', 'der_arzt',
          examples: {ExampleSlot.baseStatement, ExampleSlot.pluralStatement}),
      card('a1_k02', 'die_musik', examples: {ExampleSlot.baseStatement, ExampleSlot.baseQa}),
      card('a1_k02', 'singen', type: 'verb', examples: {ExampleSlot.baseStatement}),
      card('a1_k02', 'mit', type: 'other', examples: {}),
    ]);

    Future<List<String>> keys({String? type, Set<ExampleSlot> require = const {}}) async => [
          for (final c in await database.cards.cardsInPack('a1_k02', type: type, require: require))
            c.key,
        ];

    expect(await keys(type: 'verb'), ['singen']);
    expect(await keys(require: {ExampleSlot.baseStatement}), ['der_arzt', 'die_musik', 'singen']);
    expect(await keys(require: {ExampleSlot.pluralStatement}), ['der_arzt']);
    expect(await keys(type: 'noun', require: {ExampleSlot.baseQa}), ['die_musik']);
    expect(await keys(type: 'verb', require: {ExampleSlot.baseQa}), isEmpty);
  });

  test('card rows round-trip every field', () async {
    final original = card('a1_k02', 'die_aerztin',
        examples: {ExampleSlot.feminineStatement, ExampleSlot.feminineQa, ExampleSlot.pluralQa});
    await database.packs.replacePack(packInput('a1_k02'), [original]);

    final read = (await database.cards.getCard('a1_k02__die_aerztin'))!;
    expect(read.toRow(), original.toRow());
    expect(await database.cards.getCard('a1_k02__nope'), isNull);
  });

  group('alsoIn', () {
    setUp(() async {
      await database.packs.replacePack(packInput('a1_k02'), [
        card('a1_k02', 'der_freund'),
        card('a1_k02', 'gehen', type: 'verb'),
      ]);
      await database.packs.replacePack(packInput('a1_nb01'), [
        card('a1_nb01', 'der_freund'),
        card('a1_nb01', 'gehen_2', type: 'verb'),
      ]);
      await database.packs.replacePack(packInput('a2_k01'), [card('a2_k01', 'der_freund')]);
      await database.packs.replacePack(packInput('a1_k05'), [card('a1_k05', 'der_freund')]);
    });

    test('lists the other packs with the key, in pack sort order', () async {
      expect(await database.cards.alsoIn('der_freund', 'a1_k02'), ['a1_k05', 'a1_nb01', 'a2_k01']);
      expect(await database.cards.alsoIn('der_freund', 'a2_k01'), ['a1_k02', 'a1_k05', 'a1_nb01']);
    });

    test('leaves out unavailable packs', () async {
      await database.packs.setAvailable('a1_nb01', false);
      expect(await database.cards.alsoIn('der_freund', 'a1_k02'), ['a1_k05', 'a2_k01']);
    });

    test('treats homonym keys as different words', () async {
      expect(await database.cards.alsoIn('gehen', 'a1_k02'), isEmpty);
      expect(await database.cards.alsoIn('gehen_2', 'a1_nb01'), isEmpty);
    });
  });
}
