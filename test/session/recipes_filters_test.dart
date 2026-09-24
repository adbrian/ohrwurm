// A7 (APP_SPEC 9, 15): every words / focus / style combination, and cards lacking examples
// excluded. Checked against an independent reading of the manifests.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/packs/manifest.dart';
import 'package:ohrwurm/session/deck_builder.dart';
import 'package:ohrwurm/session/session_cards.dart';

import '../data/test_db.dart';
import 'session_test_kit.dart';

Map<String, String> _line(String text) => {
  'text': text,
  'audio': '${text.replaceAll(' ', '_')}.ogg',
};

Map<String, Object> _example(int n, String form, String kind) => kind == 'statement'
    ? {
        'n': n,
        'form': form,
        'kind': 'statement',
        'origin': 'generated',
        'source': _line('$n $form de'),
        'target': _line('$n $form en'),
      }
    : {
        'n': n,
        'form': form,
        'kind': 'qa',
        'origin': 'generated',
        'question': {'source': _line('$n $form q de'), 'target': _line('$n $form q en')},
        'answer': {'source': _line('$n $form a de'), 'target': _line('$n $form a en')},
      };

/// A pack with nouns covering every form and kind, alone and together, so plural and feminine
/// Q&A recipes have cards to find: the fixture packs have none.
Map<String, Object> syntheticManifest() {
  const combos = <String, List<(String, String)>>{
    'der_arzt': [
      ('base', 'statement'),
      ('base', 'qa'),
      ('plural', 'statement'),
      ('plural', 'qa'),
      ('feminine', 'statement'),
      ('feminine', 'qa'),
    ],
    'der_lehrer': [('base', 'qa'), ('plural', 'qa'), ('feminine', 'qa')],
    'das_kind': [('base', 'statement'), ('plural', 'statement')],
    'der_koch': [('plural', 'statement'), ('feminine', 'statement')],
    'die_katze': [('base', 'statement'), ('base', 'statement'), ('plural', 'qa')],
    'arbeiten': [('base', 'statement'), ('base', 'qa')],
  };
  return {
    'pack_id': 'b1_k05',
    'level': 'b1',
    'kind': 'textbook',
    'number': 5,
    'audio_format': 'opus',
    'generated_at': '2026-09-24T10:00:00Z',
    'cards': [
      for (final MapEntry(:key, :value) in combos.entries)
        {
          'id': 'b1_k05__$key',
          'key': key,
          'type': key == 'arbeiten' ? 'verb' : 'noun',
          'added_at': '2026-09-24',
          'word': _line(key),
          'translation': _line('$key en'),
          'examples': [for (final (i, (form, kind)) in value.indexed) _example(i + 1, form, kind)],
        },
    ],
  };
}

/// Independently of the app's code: whether [card] (manifest JSON) belongs in a Listen session
/// of these options, and how many lines its recipe plays.
int? expectedLines(
  Map<String, dynamic> card,
  Words words,
  WordFocus focus,
  Style style,
  QaTranslate qa,
) {
  final type = card['type'] as String;
  final wordsOk = switch (words) {
    Words.all => true,
    Words.noun => type == 'noun',
    Words.verb => type == 'verb',
    Words.other => type == 'other',
  };
  if (!wordsOk) return null;
  final focusApplies = words == Words.all || words == Words.noun;
  final forms = ['base', if (focusApplies && focus != WordFocus.base) focus.name];
  if (forms.length > 1 && type != 'noun') return null;
  final examples = (card['examples'] as List).cast<Map<String, dynamic>>();
  var lines = 2;
  for (final form in forms) {
    if (!examples.any((e) => e['form'] == form && e['kind'] == style.name)) return null;
    lines += style == Style.statement ? 2 : (qa == QaTranslate.both ? 4 : 3);
  }
  return lines;
}

void main() {
  late AppDatabase db;
  late SessionKit kit;
  late DeckBuilder deck;
  late Map<String, Map<String, dynamic>> manifestCards;

  const packs = ['a1_k02', 'a1_nb01', 'b1_k05'];

  setUp(() async {
    db = await openTestDatabase(FakeClock());
    kit = await SessionKit.open(db);
    final synthetic = PackManifest.read(syntheticManifest());
    await db.packs.replacePack(synthetic.pack, synthetic.cards);
    deck = DeckBuilder(cards: db.cards, progress: db.progress);
    manifestCards = {};
    for (final id in packs) {
      final rows = await db.cards.cardsInPack(id);
      for (final r in rows) {
        manifestCards[r.cardId] = jsonDecode(r.contentJson) as Map<String, dynamic>;
      }
    }
  });

  tearDown(() async {
    kit.dispose();
    await db.close();
  });

  for (final words in Words.values) {
    for (final focus in WordFocus.values) {
      for (final style in Style.values) {
        for (final qa in QaTranslate.values) {
          test('Listen: ${words.name} / ${focus.name} / ${style.name} / ${qa.name}', () async {
            final o = SessionOptions(
              mode: SessionMode.listen,
              packIds: packs,
              words: words,
              focus: focus,
              style: style,
              qaTranslate: qa,
              deckOrder: DeckOrder.sequential,
              cardMode: CardMode.looped,
              unheardFirst: false,
            );
            final expected = {
              for (final MapEntry(:key, :value) in manifestCards.entries)
                if (expectedLines(value, words, focus, style, qa) != null)
                  key: expectedLines(value, words, focus, style, qa)!,
            };
            final ids = await deck.build(o);
            expect(ids.toSet(), expected.keys.toSet());
            // Pack selection order, then manifest order.
            expect(ids, [
              for (final id in manifestCards.keys)
                if (expected.containsKey(id)) id,
            ]);

            final opened = await openSession(
              await db.session.start(o, ids),
              cards: db.cards,
              packs: db.packs,
              clips: kit.sessions.clips,
            );
            final listen = ListenCards(opened.cards, recipeFor(o), qa);
            for (var i = 0; i < listen.length; i++) {
              expect(
                listen.steps(i),
                hasLength(expected[listen.cards[i].row.cardId]),
                reason: listen.cards[i].row.cardId,
              );
            }
          });
        }
      }
    }
  }

  for (final style in Style.values) {
    test('Mirror, ${style.name}: cards with a base ${style.name}, any focus', () async {
      for (final focus in WordFocus.values) {
        final ids = await deck.build(
          SessionOptions(
            mode: SessionMode.mirror,
            packIds: packs,
            words: Words.all,
            focus: focus,
            style: style,
            qaTranslate: QaTranslate.both,
            deckOrder: DeckOrder.sequential,
            cardMode: CardMode.looped,
            unheardFirst: false,
          ),
        );
        expect(ids, [
          for (final MapEntry(:key, :value) in manifestCards.entries)
            if ((value['examples'] as List).any(
              (e) => e['form'] == 'base' && e['kind'] == style.name,
            ))
              key,
        ]);
      }
    });
  }
}
