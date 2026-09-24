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

  const options = SessionOptions(
    mode: SessionMode.listen,
    packIds: ['a1_nb01', 'a1_k02'],
    words: Words.noun,
    focus: WordFocus.plural,
    style: Style.qa,
    qaTranslate: QaTranslate.question,
    deckOrder: DeckOrder.shuffled,
    cardMode: CardMode.continuous,
    cardLimit: 20,
    unheardFirst: true,
  );
  const order = ['a1_k02__der_arzt', 'a1_nb01__die_leute', 'a1_k02__der_freund'];

  test('there is no session at first', () async {
    expect(await database.session.load(), isNull);
  });

  test('a started session loads back exactly', () async {
    await database.session.start(options, order);

    final session = (await database.session.load())!;
    final o = session.options;
    expect(o.mode, SessionMode.listen);
    expect(o.packIds, ['a1_nb01', 'a1_k02']);
    expect(o.words, Words.noun);
    expect(o.focus, WordFocus.plural);
    expect(o.style, Style.qa);
    expect(o.qaTranslate, QaTranslate.question);
    expect(o.deckOrder, DeckOrder.shuffled);
    expect(o.cardMode, CardMode.continuous);
    expect(o.cardLimit, 20);
    expect(o.unheardFirst, isTrue);
    expect(session.cardOrder, order);
    expect(session.position, 0);
    expect(session.createdAt, '2026-09-24T08:00:00.000Z');
    expect(session.lastOpenedAt, '2026-09-24T08:00:00.000Z');
  });

  test('no card limit is stored as null', () async {
    await database.session.start(
      const SessionOptions(
        mode: SessionMode.mirror,
        packIds: ['a1_k02'],
        words: Words.all,
        focus: WordFocus.base,
        style: Style.statement,
        qaTranslate: QaTranslate.both,
        deckOrder: DeckOrder.sequential,
        cardMode: CardMode.looped,
        unheardFirst: false,
      ),
      order,
    );
    final o = (await database.session.load())!.options;
    expect(o.cardLimit, isNull);
    expect(o.mode, SessionMode.mirror);
    expect(o.unheardFirst, isFalse);
  });

  test('position and last-opened time are updated in place', () async {
    await database.session.start(options, order);
    await database.session.setPosition(2);
    clock.advance(const Duration(hours: 5));
    await database.session.touch();

    final session = (await database.session.load())!;
    expect(session.position, 2);
    expect(session.createdAt, '2026-09-24T08:00:00.000Z');
    expect(session.lastOpenedAt, '2026-09-24T13:00:00.000Z');
  });

  test('starting a session replaces the previous one', () async {
    await database.session.start(options, order);
    await database.session.setPosition(2);
    clock.advance();
    await database.session.start(options, ['a1_k02__singen']);

    final session = (await database.session.load())!;
    expect(session.cardOrder, ['a1_k02__singen']);
    expect(session.position, 0);
    expect(session.createdAt, '2026-09-24T08:01:00.000Z');
    expect(await database.db.query('session'), hasLength(1));
  });

  test('clear removes the session', () async {
    await database.session.start(options, order);
    await database.session.clear();
    expect(await database.session.load(), isNull);
  });
}
