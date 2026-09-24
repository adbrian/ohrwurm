/// Single-point breakages of `test/fixtures/packs/a1_k02/manifest.json`, each of which the
/// schema must reject. Built at test time from the valid fixture, so they follow it when it's
/// regenerated.
///
/// Plain Dart with no package imports, so the same list can be dumped and checked against
/// Python `jsonschema`, the pipeline's validator.
library;

import 'dart:convert';

typedef Manifest = Map<String, dynamic>;

/// Each breakage's name, and the change it makes to a deep copy of the valid manifest.
final breakages = <String, void Function(Manifest m)>{
  'missing required field': (m) => m.remove('generated_at'),
  'unknown top-level field': (m) => m['surprise'] = true,
  'wrong schema_version': (m) => m['schema_version'] = 1,
  'pack_id not matching the pattern': (m) => m['pack_id'] = 'a1_kapitel2',
  'unknown level': (m) => m['level'] = 'c1',
  'unknown kind': (m) => m['kind'] = 'workbook',
  'number as a string': (m) => m['number'] = '2',
  'empty title': (m) => m['title'] = '',
  'voices missing en': (m) => (m['voices'] as Manifest).remove('en'),
  'unknown card field': (m) => _card(m, 0)['colour'] = 'blue',
  'card id not matching the pattern': (m) => _card(m, 0)['id'] = 'A1_K02-der-Freund',
  'card key with a capital': (m) => _card(m, 0)['key'] = 'der_Freund',
  'unknown card type': (m) => _card(m, 0)['type'] = 'adjective',
  'line without audio': (m) => (_card(m, 0)['word'] as Manifest).remove('audio'),
  'line with empty text': (m) => (_card(m, 0)['translation'] as Manifest)['text'] = '',
  'unknown line field': (m) => (_card(m, 0)['word'] as Manifest)['voice'] = 'Katja',
  'unknown article': (m) => _grammar(m, 0)['article'] = 'den',
  'plural_only with an article': (m) => _grammar(m, 0)['plural_only'] = true,
  'no_plural with a plural': (m) => _grammar(m, 0)['no_plural'] = true,
  'no_article false': (m) => _grammar(m, 0)
    ..remove('article')
    ..['no_article'] = false,
  'noun grammar on a verb': (m) => _grammar(m, 1)['plural'] = 'die Singen',
  'grammar on an other': (m) => _card(m, 3)['grammar'] = <String, dynamic>{},
  'statement without a target': (m) => _example(m, 0, 0).remove('target'),
  'statement with a question': (m) =>
      _example(m, 0, 0)['question'] = jsonDecode(jsonEncode(_example(m, 0, 1)['question'])),
  'Q&A with a source': (m) =>
      _example(m, 0, 1)['source'] = jsonDecode(jsonEncode(_example(m, 0, 0)['source'])),
};

/// A deep copy of [valid] with the breakage [name] applied.
Manifest broken(Manifest valid, String name) {
  final copy = jsonDecode(jsonEncode(valid)) as Manifest;
  breakages[name]!(copy);
  return copy;
}

Manifest _card(Manifest m, int i) => (m['cards'] as List)[i] as Manifest;

Manifest _grammar(Manifest m, int i) => _card(m, i)['grammar'] as Manifest;

Manifest _example(Manifest m, int card, int i) => (_card(m, card)['examples'] as List)[i] as Manifest;
