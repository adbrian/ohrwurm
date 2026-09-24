import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/session/deck_builder.dart';
import 'package:ohrwurm/session/launch.dart';

import '../data/test_db.dart';
import 'session_test_kit.dart';

SessionOptions options(
  List<String> packs, {
  SessionMode mode = SessionMode.listen,
  Words words = Words.all,
  WordFocus focus = WordFocus.base,
  Style style = Style.statement,
  DeckOrder order = DeckOrder.sequential,
  int? limit,
  bool unheardFirst = false,
}) => SessionOptions(
  mode: mode,
  packIds: packs,
  words: words,
  focus: focus,
  style: style,
  qaTranslate: QaTranslate.both,
  deckOrder: order,
  cardMode: CardMode.looped,
  cardLimit: limit,
  unheardFirst: unheardFirst,
);

void main() {
  late AppDatabase db;
  late SessionKit kit;
  late DeckBuilder deck;

  setUp(() async {
    db = await openTestDatabase(FakeClock());
    kit = await SessionKit.open(db);
    deck = DeckBuilder(cards: db.cards, progress: db.progress, random: Random(7));
  });

  tearDown(() async {
    kit.dispose();
    await db.close();
  });

  test('the defaults are those of APP_SPEC 10.1', () {
    final o = defaultOptions(['a1_k02']);
    expect(o.mode, SessionMode.listen);
    expect(o.words, Words.all);
    expect(o.focus, WordFocus.base);
    expect(o.style, Style.statement);
    expect(o.qaTranslate, QaTranslate.both);
    expect(o.deckOrder, DeckOrder.sequential);
    expect(o.cardMode, CardMode.looped);
    expect(o.cardLimit, isNull);
    expect(o.unheardFirst, isFalse);
  });

  test('in order: packs in selection order, cards in manifest order', () async {
    expect(await deck.build(options(['a1_nb01', 'a1_k02'])), [
      'a1_nb01__der_freund', 'a1_nb01__die_leute', 'a1_nb01__fussball', 'a1_nb01__gehen',
      'a1_nb01__in', //
      'a1_k02__der_freund', 'a1_k02__singen', 'a1_k02__heissen',
    ]);
  });

  test('cards lacking the recipe\'s examples are excluded', () async {
    // gern has only a Q&A; gehen_2 too.
    final ids = await deck.build(options(['a1_k02', 'a1_nb01']));
    expect(ids, isNot(contains('a1_k02__gern')));
    expect(ids, isNot(contains('a1_nb01__gehen_2')));
    expect(await deck.build(options(['a1_k02', 'a1_nb01'], style: Style.qa)), [
      'a1_k02__der_freund', 'a1_k02__gern', 'a1_nb01__gehen', 'a1_nb01__gehen_2', //
    ]);
  });

  test('words filters by type', () async {
    expect(await deck.build(options(['a1_k02', 'a1_nb01'], words: Words.verb)), [
      'a1_k02__singen',
      'a1_k02__heissen',
      'a1_nb01__gehen',
    ]);
    expect(await deck.build(options(['a1_k02', 'a1_nb01'], words: Words.other)), ['a1_nb01__in']);
    expect(await deck.build(options(['a1_nb01'], words: Words.noun)), [
      'a1_nb01__der_freund',
      'a1_nb01__die_leute',
      'a1_nb01__fussball',
    ]);
  });

  test('plural and feminine focus contain only nouns with such an example', () async {
    expect(await deck.build(options(['a1_k02', 'a1_nb01'], focus: WordFocus.plural)), [
      'a1_k02__der_freund',
    ]);
    expect(await deck.build(options(['a1_k02', 'a1_nb01'], focus: WordFocus.feminine)), [
      'a1_k02__der_freund',
    ]);
    expect(
      await deck.build(options(['a1_k02', 'a1_nb01'], focus: WordFocus.plural, style: Style.qa)),
      isEmpty,
    );
  });

  test('focus applies only with Words all or nouns, and only in Listen', () async {
    final verbs = options(['a1_k02'], words: Words.verb, focus: WordFocus.plural);
    expect(focusApplies(verbs), isFalse);
    expect(await deck.build(verbs), ['a1_k02__singen', 'a1_k02__heissen']);
    final mirror = options(['a1_k02'], mode: SessionMode.mirror, focus: WordFocus.plural);
    expect(focusApplies(mirror), isFalse);
    expect(await deck.build(mirror), ['a1_k02__der_freund', 'a1_k02__singen', 'a1_k02__heissen']);
  });

  test('mirror requires the base example of its style', () async {
    expect(await deck.build(options(['a1_k02'], mode: SessionMode.mirror, style: Style.qa)), [
      'a1_k02__der_freund',
      'a1_k02__gern',
    ]);
  });

  test('a word in two selected packs appears twice', () async {
    final ids = await deck.build(options(['a1_k02', 'a1_nb01']));
    expect(ids.where((id) => id.endsWith('__der_freund')), hasLength(2));
  });

  test('shuffled mixes cards from all selected packs, once', () async {
    final inOrder = await deck.build(options(['a1_k02', 'a1_nb01']));
    final shuffled = await deck.build(options(['a1_k02', 'a1_nb01'], order: DeckOrder.shuffled));
    expect(shuffled, unorderedEquals(inOrder));
    expect(shuffled, isNot(inOrder));
  });

  test('unheard first moves unheard words to the front, keeping the order in each group', () async {
    await db.progress.markHeard('der_freund');
    await db.progress.markHeard('singen');
    expect(await deck.build(options(['a1_k02', 'a1_nb01'], unheardFirst: true)), [
      'a1_k02__heissen', 'a1_nb01__die_leute', 'a1_nb01__fussball', 'a1_nb01__gehen',
      'a1_nb01__in', //
      'a1_k02__der_freund', 'a1_k02__singen', 'a1_nb01__der_freund',
    ]);
  });

  test('the card limit truncates after unheard first', () async {
    await db.progress.markHeard('der_freund');
    expect(await deck.build(options(['a1_k02', 'a1_nb01'], unheardFirst: true, limit: 3)), [
      'a1_k02__singen',
      'a1_k02__heissen',
      'a1_nb01__die_leute',
    ]);
    expect(await deck.build(options(['a1_k02'], limit: 10)), hasLength(3));
  });

  test('reshuffle gives a new order of the same cards', () {
    final order = ['a', 'b', 'c', 'd', 'e', 'f'];
    final again = deck.reshuffle(order);
    expect(again, unorderedEquals(order));
    expect(again, isNot(order));
  });
}
