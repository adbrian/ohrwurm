/// Recipes (APP_SPEC 9): which lines a card plays, in what order. Recipes are data — the table in
/// [Recipe.of] — never branches in the engine, which only ever sees a list of steps.
library;

import '../data/models.dart';
import '../playback/listen_engine.dart';
import 'card_content.dart';

/// A line as a recipe plays it and the Listen card shows it.
class RecipeLine {
  final Line line;
  final LineRole role;

  /// 0 for the word and translation; then 1, 2… for each example, so the card can space them
  /// (DESIGN 5).
  final int group;

  const RecipeLine(this.line, this.role, this.group);

  bool get german => role == LineRole.word || role == LineRole.germanSentence;
}

/// An example a recipe needs: its form and kind (APP_SPEC 4.7).
typedef ExampleNeed = ({String form, String kind});

class Recipe {
  /// After the word and the translation, the examples in the order they play.
  final List<ExampleNeed> examples;

  const Recipe(this.examples);

  /// The recipe the session's focus and style select (APP_SPEC 9's table).
  static Recipe of(WordFocus focus, Style style) {
    final kind = style.name;
    return Recipe([
      (form: 'base', kind: kind),
      if (focus != WordFocus.base) (form: focus.name, kind: kind),
    ]);
  }

  /// The `has_*` flags a card needs for this recipe, so filtering is a query (APP_SPEC 6).
  Set<ExampleSlot> get requires => {for (final e in examples) slotOf(e.form, e.kind)};

  /// The card's lines in the order they play, or null when the card lacks an example this recipe
  /// needs: such a card is excluded, never played partially (APP_SPEC 9). Each recipe uses the
  /// first example of each form and kind.
  List<RecipeLine>? lines(CardContent card, QaTranslate qaTranslate) {
    final out = [
      RecipeLine(card.word, LineRole.word, 0),
      RecipeLine(card.translation, LineRole.translation, 0),
    ];
    for (final (i, need) in examples.indexed) {
      final group = i + 1;
      switch (card.firstExample(need.form, need.kind)) {
        case null:
          return null;
        case StatementExample(:final pair):
          out.addAll(_pair(pair, group));
        case QaExample(:final question, :final answer):
          out.addAll(_pair(question, group));
          out.add(RecipeLine(answer.source, LineRole.germanSentence, group));
          if (qaTranslate == QaTranslate.both) {
            out.add(RecipeLine(answer.target, LineRole.englishSentence, group));
          }
      }
    }
    return out;
  }

  static List<RecipeLine> _pair(Pair p, int group) => [
    RecipeLine(p.source, LineRole.germanSentence, group),
    RecipeLine(p.target, LineRole.englishSentence, group),
  ];
}

ExampleSlot slotOf(String form, String kind) => switch ((form, kind)) {
  ('base', 'statement') => ExampleSlot.baseStatement,
  ('base', 'qa') => ExampleSlot.baseQa,
  ('plural', 'statement') => ExampleSlot.pluralStatement,
  ('plural', 'qa') => ExampleSlot.pluralQa,
  ('feminine', 'statement') => ExampleSlot.feminineStatement,
  ('feminine', 'qa') => ExampleSlot.feminineQa,
  _ => throw ArgumentError('Unknown example form/kind: $form/$kind'),
};
