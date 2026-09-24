import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/cards/card_content.dart';
import 'package:ohrwurm/cards/recipe.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/playback/listen_engine.dart';

import 'fixture_cards.dart';

Map<String, String> _line(String text) => {'text': text, 'audio': '$text.ogg'};

Map<String, Object> _statement(int n, String form, String tag) => {
  'n': n,
  'form': form,
  'kind': 'statement',
  'origin': 'generated',
  'source': _line('$tag de'),
  'target': _line('$tag en'),
};

Map<String, Object> _qa(int n, String form, String tag) => {
  'n': n,
  'form': form,
  'kind': 'qa',
  'origin': 'generated',
  'question': {'source': _line('$tag q de'), 'target': _line('$tag q en')},
  'answer': {'source': _line('$tag a de'), 'target': _line('$tag a en')},
};

/// A noun with every form and kind, and a second base statement.
final everything = CardContent.fromJson(
  jsonEncode({
    'id': 'a1_k01__der_arzt',
    'key': 'der_arzt',
    'type': 'noun',
    'added_at': '2026-09-01',
    'word': _line('der Arzt'),
    'translation': _line('doctor'),
    'grammar': {'article': 'der', 'plural': 'die Ärzte'},
    'examples': [
      _statement(1, 'base', 'base1'),
      _statement(2, 'base', 'base2'),
      _qa(3, 'base', 'base'),
      _statement(4, 'plural', 'plural'),
      _qa(5, 'plural', 'plural'),
      _statement(6, 'feminine', 'fem'),
      _qa(7, 'feminine', 'fem'),
    ],
  }),
);

List<String> texts(List<RecipeLine>? lines) => [for (final l in lines!) l.line.text];

void main() {
  group('the six recipes (APP_SPEC 9)', () {
    const head = ['der Arzt', 'doctor'];

    test('statement / base: word → translation → base statement', () {
      expect(
        texts(Recipe.of(WordFocus.base, Style.statement).lines(everything, QaTranslate.both)),
        [...head, 'base1 de', 'base1 en'],
      );
    });

    test('statement / plural: … → base statement → plural statement', () {
      expect(
        texts(Recipe.of(WordFocus.plural, Style.statement).lines(everything, QaTranslate.both)),
        [...head, 'base1 de', 'base1 en', 'plural de', 'plural en'],
      );
    });

    test('statement / feminine: … → base statement → feminine statement', () {
      expect(
        texts(Recipe.of(WordFocus.feminine, Style.statement).lines(everything, QaTranslate.both)),
        [...head, 'base1 de', 'base1 en', 'fem de', 'fem en'],
      );
    });

    test('qa / base: word → translation → base Q&A', () {
      expect(texts(Recipe.of(WordFocus.base, Style.qa).lines(everything, QaTranslate.both)), [
        ...head,
        'base q de',
        'base q en',
        'base a de',
        'base a en',
      ]);
    });

    test('qa / plural: … → base Q&A → plural Q&A', () {
      expect(texts(Recipe.of(WordFocus.plural, Style.qa).lines(everything, QaTranslate.both)), [
        ...head,
        'base q de', 'base q en', 'base a de', 'base a en', //
        'plural q de', 'plural q en', 'plural a de', 'plural a en',
      ]);
    });

    test('qa / feminine: … → base Q&A → feminine Q&A', () {
      expect(texts(Recipe.of(WordFocus.feminine, Style.qa).lines(everything, QaTranslate.both)), [
        ...head,
        'base q de', 'base q en', 'base a de', 'base a en', //
        'fem q de', 'fem q en', 'fem a de', 'fem a en',
      ]);
    });
  });

  test("question only skips the answer's English", () {
    expect(texts(Recipe.of(WordFocus.plural, Style.qa).lines(everything, QaTranslate.question)), [
      'der Arzt', 'doctor', //
      'base q de', 'base q en', 'base a de',
      'plural q de', 'plural q en', 'plural a de',
    ]);
  });

  test('roles set the pauses: word, translation, German and English sentences', () {
    final lines = Recipe.of(WordFocus.base, Style.statement).lines(everything, QaTranslate.both)!;
    expect(
      [for (final l in lines) l.role],
      [LineRole.word, LineRole.translation, LineRole.germanSentence, LineRole.englishSentence],
    );
    expect([for (final l in lines) l.german], [true, false, true, false]);
    expect([for (final l in lines) l.group], [0, 0, 1, 1]);
  });

  test('a card lacking a required example is excluded, never played partially', () {
    final singen = fixtureCard('a1_k02', 'singen');
    expect(Recipe.of(WordFocus.base, Style.statement).lines(singen, QaTranslate.both), isNotNull);
    expect(Recipe.of(WordFocus.base, Style.qa).lines(singen, QaTranslate.both), isNull);
    final freund = fixtureCard('a1_k02', 'der_freund');
    expect(Recipe.of(WordFocus.plural, Style.qa).lines(freund, QaTranslate.both), isNull);
  });

  test('each recipe uses the first example of each form and kind', () {
    final lines = Recipe.of(WordFocus.base, Style.statement).lines(everything, QaTranslate.both)!;
    expect(texts(lines), isNot(contains('base2 de')));
  });

  test('a recipe requires the flags of its examples', () {
    expect(Recipe.of(WordFocus.base, Style.statement).requires, {ExampleSlot.baseStatement});
    expect(Recipe.of(WordFocus.plural, Style.qa).requires, {
      ExampleSlot.baseQa,
      ExampleSlot.pluralQa,
    });
    expect(Recipe.of(WordFocus.feminine, Style.statement).requires, {
      ExampleSlot.baseStatement,
      ExampleSlot.feminineStatement,
    });
  });
}
