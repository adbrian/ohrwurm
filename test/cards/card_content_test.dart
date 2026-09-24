import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/cards/card_content.dart';

import 'fixture_cards.dart';

void main() {
  group('grammar line (APP_SPEC 13)', () {
    test('noun: plural, then feminine with its translation', () {
      expect(
        fixtureCard('a1_k02', 'der_freund').grammarLine,
        'die Freunde · die Freundin · female friend, girlfriend',
      );
    });

    test('noun: plural only', () {
      expect(fixtureCard('a1_nb01', 'die_leute').grammarLine, 'plural only');
    });

    test('noun: no plural, no article', () {
      expect(fixtureCard('a1_nb01', 'fussball').grammarLine, 'no plural · no article');
    });

    test('noun with just a plural', () {
      expect(fixtureCard('a1_nb01', 'der_freund').grammarLine, 'die Freunde');
    });

    test('verb: present and perfect', () {
      expect(fixtureCard('a1_k02', 'singen').grammarLine, 'er singt · hat gesungen');
    });

    test('note, for any type', () {
      expect(fixtureCard('a1_nb01', 'in').grammarLine, '+ Dativ');
    });

    test('nothing to show', () {
      expect(fixtureCard('a1_k02', 'gern').grammarLine, isNull);
    });
  });

  test('the headword is the text, article included (APP_SPEC 13)', () {
    final card = fixtureCard('a1_k02', 'der_freund');
    expect(card.word.text, 'der Freund');
    expect(card.word.audio, 'a1_k02__der_freund__word.ogg');
  });

  test('spoken is never read: only text is kept (CLAUDE.md, rule 4)', () {
    final json = fixtureCardJson('a1_k02', 'heissen');
    expect(json, contains('"spoken"'), reason: 'the fixture has a spoken form');
    final card = CardContent.fromJson(json);
    expect(card.translation.text, 'to be named / called');
    final texts = [
      card.word.text,
      card.translation.text,
      for (final e in card.examples)
        if (e is StatementExample) ...[e.pair.source.text, e.pair.target.text],
    ];
    expect(texts, isNot(contains('to be named, or called')));
  });

  test('the first example of a form and kind', () {
    final card = fixtureCard('a1_k02', 'der_freund');
    expect(card.firstExample('base', 'statement')!.n, 1);
    expect(card.firstExample('base', 'qa')!.n, 2);
    expect(card.firstExample('plural', 'qa'), isNull);
  });
}
