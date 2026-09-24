/// A card's content as the manifest gives it (APP_SPEC 4.4–4.7), read from `content_json`.
///
/// Lines keep `text` and `audio` only. `spoken` exists for audio generation and is never read,
/// so it can't be displayed (CLAUDE.md, rule 4). `origin` and `tags` aren't displayed in v1 and
/// aren't read either.
library;

import 'dart:convert';

/// One line: the text to show, and its clip's filename inside the pack folder (APP_SPEC 4.6).
class Line {
  final String text;
  final String audio;

  const Line(this.text, this.audio);

  static Line _read(Object? json) {
    final m = json as Map<String, dynamic>;
    return Line(m['text'] as String, m['audio'] as String);
  }
}

/// A German line and its English (APP_SPEC 4.7).
class Pair {
  final Line source;
  final Line target;

  const Pair(this.source, this.target);

  static Pair _read(Object? json) {
    final m = json as Map<String, dynamic>;
    return Pair(Line._read(m['source']), Line._read(m['target']));
  }
}

sealed class Example {
  final int n;
  final String form;

  const Example(this.n, this.form);

  String get kind;

  static Example _read(Map<String, dynamic> m) {
    final n = m['n'] as int;
    final form = m['form'] as String;
    return switch (m['kind'] as String) {
      'qa' => QaExample(n, form, Pair._read(m['question']), Pair._read(m['answer'])),
      _ => StatementExample(n, form, Pair(Line._read(m['source']), Line._read(m['target']))),
    };
  }
}

class StatementExample extends Example {
  final Pair pair;

  const StatementExample(super.n, super.form, this.pair);

  @override
  String get kind => 'statement';
}

class QaExample extends Example {
  final Pair question;
  final Pair answer;

  const QaExample(super.n, super.form, this.question, this.answer);

  @override
  String get kind => 'qa';
}

class CardContent {
  final String id;
  final String key;
  final String type;
  final Line word;
  final Line translation;

  /// Nouns and verbs only (APP_SPEC 4.5); empty otherwise.
  final Map<String, dynamic> grammar;
  final String? note;

  /// In manifest order.
  final List<Example> examples;

  const CardContent({
    required this.id,
    required this.key,
    required this.type,
    required this.word,
    required this.translation,
    required this.grammar,
    this.note,
    required this.examples,
  });

  factory CardContent.fromJson(String contentJson) {
    final m = jsonDecode(contentJson) as Map<String, dynamic>;
    return CardContent(
      id: m['id'] as String,
      key: m['key'] as String,
      type: m['type'] as String,
      word: Line._read(m['word']),
      translation: Line._read(m['translation']),
      grammar: (m['grammar'] as Map<String, dynamic>?) ?? const {},
      note: m['note'] as String?,
      examples: [
        for (final e in (m['examples'] as List).cast<Map<String, dynamic>>()) Example._read(e),
      ],
    );
  }

  /// The first example of [form] and [kind], which is the one a recipe uses (APP_SPEC 9).
  Example? firstExample(String form, String kind) =>
      examples.where((e) => e.form == form && e.kind == kind).firstOrNull;

  /// The grammar line beneath the headword (APP_SPEC 13, DESIGN 5), or null when there's nothing
  /// to show: *die Ärzte · die Ärztin · waitress*, *er singt · hat gesungen*, *+ Dativ*.
  String? get grammarLine {
    final g = grammar;
    final parts = <String>[
      if (type == 'noun') ...[
        if (g['plural_only'] == true)
          'plural only'
        else if (g['no_plural'] == true)
          'no plural'
        else if (g['plural'] is String)
          g['plural'] as String,
        if (g['no_article'] == true) 'no article',
        if (g['feminine'] is String)
          [g['feminine'] as String, ?(g['feminine_translation'] as String?)].join(' · '),
      ],
      if (type == 'verb') ...[
        if (g['present_3sg'] is String) g['present_3sg'] as String,
        if (g['perfect'] is String) g['perfect'] as String,
      ],
      ?note,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
