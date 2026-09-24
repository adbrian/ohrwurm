/// Wording for the session screens (DESIGN 3–9). Where DESIGN gives the words they're used as
/// written; the rest was written in DESIGN's voice by Claude in the autonomous run, for Ian to
/// review (STATUS, 2026-09-24).
library;

import '../data/models.dart';
import 'deck_builder.dart';

abstract final class SessionCopy {
  // Listen card (DESIGN 5, 6).
  static const listening = 'Listening…';
  static const yourTurn = 'Your turn — understand it before the English';
  static const looping = "Looping — swipe when you're ready";
  static const movingOn = 'Moving on…';
  static const replaying = 'Replaying…';
  static const clipFailed =
      "This line couldn't be played. The pack may have changed since it "
      'was loaded. Rescan to check it, or swipe for the next card.';
  static const loop = 'Loop';
  static const again = 'Again';
  static const next = 'Next';
  static const listenHint = 'Swipe either way for the next card · tap to replay';
  static const mirrorHint = 'Swipe for the next card';
  static const back = 'Back';
  static const opening = 'Opening your session…';

  static String cardOf(int number, int total) => 'Card $number of $total';

  // Mirror card (DESIGN 7).
  static const play = 'Play';
  static const record = 'Record';
  static const stop = 'Stop';
  static const playMine = 'Play mine';
  static const question = 'QUESTION';
  static const answer = 'ANSWER';
  static const micDenied =
      'Recording needs the microphone. Ohrwurm uses it only to let you '
      'hear yourself, and nothing leaves the phone.';
  static const micDeniedForever =
      'Recording needs the microphone. Allow it in the phone\'s '
      'settings: Apps → Ohrwurm → Permissions → Microphone.';
  static const openSettings = 'Open settings';

  // End card (DESIGN 8).
  static const sessionDone = 'SESSION DONE';
  static const endHeading = 'That was a solid run.';
  static const restart = 'Restart';
  static const reshuffle = 'Reshuffle';
  static const changeSelection = 'Change selection';

  static String cards(int n) => n == 1 ? '1 card' : '$n cards';

  // Resume prompt (DESIGN 3).
  static const resumeKicker = 'PICK UP WHERE YOU LEFT OFF';
  static const resume = 'Resume';
  static const newSession = 'New session';
  static const mostlyGone = "Some packs aren't on this phone anymore";
  static const mostlyGoneBody =
      'Most of the cards in your last session are gone, so it '
      "can't pick up where it left off. Your progress is kept.";
  static const choosePacks = 'Choose packs';

  // Setup (DESIGN 4).
  static const setupHeading = 'Your packs';
  static const start = 'Start';
  static const settings = 'Settings';
  static const mode = 'Mode';
  static const words = 'Words';
  static const focus = 'Focus';
  static const style = 'Style';
  static const qaTranslation = 'Q&A translation';
  static const deckOrder = 'Deck order';
  static const cardMode = 'Card mode';
  static const cardLimit = 'Card limit';
  static const noLimit = 'No limit';
  static const unheardFirst = 'Unheard first';

  static String heard(int heard, int total) => '$heard / $total heard';

  static String footer(int packs, int cards) =>
      '${packs == 1 ? '1 pack' : '$packs packs'} · ${SessionCopy.cards(cards)}';

  /// Why the options match no cards, naming the option to change (DESIGN 4).
  static String noCards(SessionOptions o) {
    if (effectiveFocus(o) != WordFocus.base) {
      return 'None of these words have ${o.focus.name} examples '
          '${o.style == Style.qa ? 'as questions and answers' : 'as statements'}. '
          'Try Focus: base.';
    }
    if (o.words != Words.all) {
      return 'These packs have no ${wordsOption(o.words).toLowerCase()} with '
          '${o.style == Style.qa ? 'question-and-answer' : 'statement'} examples. '
          'Try Words: all.';
    }
    return 'None of these words have '
        '${o.style == Style.qa ? 'question-and-answer' : 'statement'} examples. '
        'Try the other Style.';
  }

  // Option values (APP_SPEC 10.1).
  static String modeOption(SessionMode v) => switch (v) {
    SessionMode.listen => 'Listen',
    SessionMode.mirror => 'Mirror',
  };

  static String wordsOption(Words v) => switch (v) {
    Words.all => 'All',
    Words.noun => 'Nouns',
    Words.verb => 'Verbs',
    Words.other => 'Other',
  };

  static String focusOption(WordFocus v) => switch (v) {
    WordFocus.base => 'Base',
    WordFocus.plural => 'Plural',
    WordFocus.feminine => 'Feminine',
  };

  static String styleOption(Style v) => switch (v) {
    Style.statement => 'Statements',
    Style.qa => 'Q&A',
  };

  static String qaOption(QaTranslate v) => switch (v) {
    QaTranslate.both => 'Question and answer',
    QaTranslate.question => 'Question only',
  };

  static String orderOption(DeckOrder v) => switch (v) {
    DeckOrder.sequential => 'In order',
    DeckOrder.shuffled => 'Shuffled',
  };

  static String cardModeOption(CardMode v) => switch (v) {
    CardMode.looped => 'Looped',
    CardMode.continuous => 'Continuous',
  };

  /// The session's main options in one line: *shuffled · loop · statements* (DESIGN 3).
  static String summary(SessionOptions o) => [
    if (o.mode == SessionMode.mirror) 'mirror',
    o.deckOrder == DeckOrder.shuffled ? 'shuffled' : 'in order',
    if (o.mode == SessionMode.listen) o.cardMode == CardMode.looped ? 'loop' : 'continuous',
    if (o.words != Words.all) wordsOption(o.words).toLowerCase(),
    if (effectiveFocus(o) != WordFocus.base) o.focus.name,
    o.style == Style.qa ? 'Q&A' : 'statements',
    if (o.unheardFirst) 'unheard first',
  ].join(' · ');
}
