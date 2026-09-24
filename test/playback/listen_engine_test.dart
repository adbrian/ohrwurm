// The engine's cancellation tests (APP_SPEC 11.6), written before the engine. A failing test here
// is a regression in the engine, never a test to adjust (CLAUDE.md, rule 2).
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/playback/listen_engine.dart';

import 'fake_clip_player.dart';

/// Cards of four lines each: word, translation, German sentence, English sentence. With 1 s
/// clips and the default pauses, a pass takes 8.1 s:
///
///     word        0.0–1.0, pause to 1.8
///     translation 1.8–2.8, pause to 3.8
///     German      3.8–4.8, pause to 6.3
///     English     6.3–7.3, pause to 8.1   → heard at 8.1
///     gap between cards 8.1–10.1          → advance at 10.1
class TestDeck implements ListenDeck {
  @override
  final int length;

  TestDeck(this.length);

  @override
  String key(int index) => 'k$index';

  @override
  List<Step> steps(int index) => [
        Step('c$index/word', LineRole.word),
        Step('c$index/translation', LineRole.translation),
        Step('c$index/de', LineRole.germanSentence),
        Step('c$index/en', LineRole.englishSentence),
      ];
}

const passMs = 8100;
const cardMs = 10100;

class Harness {
  final player = FakeClipPlayer();
  final heard = <String>[];
  final advances = <int>[];
  late final ListenEngine engine;

  Harness({int cards = 3, CardMode mode = CardMode.continuous, int position = 0}) {
    engine = ListenEngine(
      player: player,
      deck: TestDeck(cards),
      pauses: const Pauses(),
      cardMode: mode,
      position: position,
      onHeard: heard.add,
      onAdvance: advances.add,
    );
  }
}

void main() {
  test('continuous, card completes: heard once, exactly one advance', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: passMs - 50));
      expect(h.heard, isEmpty);
      async.elapse(const Duration(milliseconds: 100));
      expect(h.heard, ['k0']);
      expect(h.advances, isEmpty, reason: 'the gap between cards comes first');
      async.elapse(const Duration(milliseconds: cardMs - passMs));
      expect(h.heard, ['k0']);
      expect(h.advances, [1]);
      expect(h.engine.position, 1);
      expect(h.player.playing, 'c1/word');
    });
  });

  test('swipe mid-clip: audio stops, exactly one advance, not marked heard', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: 500));
      expect(h.player.playing, 'c0/word');
      h.engine.swipe();
      expect(h.player.stops, greaterThan(0));
      expect(h.player.playing, 'c1/word', reason: 'the old clip stopped; the next card starts');
      expect(h.advances, [1]);
      // Past the end of the interrupted clip, and of the whole interrupted card.
      async.elapse(const Duration(milliseconds: cardMs + 50));
      expect(h.advances, [1, 2], reason: 'only card 1 advancing on its own, once');
      expect(h.heard, ['k1'], reason: 'card 0 was left early');
      expect(h.player.played.where((u) => u.startsWith('c0/')), ['c0/word']);
    });
  });

  test('swipe during a pause between lines: one advance, the stale timer does nothing', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: 1400));
      expect(h.engine.phase, ListenPhase.pause);
      h.engine.swipe();
      expect(h.advances, [1]);
      // The cancelled pause would have ended at 1.8 s and played card 0's translation.
      async.elapse(const Duration(milliseconds: 2000));
      expect(h.advances, [1]);
      expect(h.player.played, isNot(contains('c0/translation')));
      expect(h.engine.position, 1);
      expect(h.engine.activeStep, 1, reason: 'card 1 is on its second line by now');
    });
  });

  test('swipe during the pause after the last line: one advance, not marked heard', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: 7800));
      expect(h.engine.phase, ListenPhase.pause);
      expect(h.engine.activeStep, 3);
      h.engine.swipe();
      // The cancelled pause would have ended at 8.1 s, counted card 0 and advanced at 10.1 s.
      async.elapse(const Duration(milliseconds: 2500));
      expect(h.heard, isEmpty);
      expect(h.advances, [1]);
    });
  });

  test('swipe during the gap between cards: exactly one advance, not two', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: 9000));
      expect(h.engine.phase, ListenPhase.gap);
      expect(h.heard, ['k0']);
      h.engine.swipe();
      expect(h.advances, [1]);
      // The cancelled gap would have advanced at 10.1 s.
      async.elapse(const Duration(milliseconds: 2000));
      expect(h.advances, [1]);
      expect(h.engine.position, 1);
    });
  });

  test('tap replay mid-card: restarts from the first line, position unchanged', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: 2000));
      expect(h.engine.activeStep, 1);
      h.engine.replay();
      expect(h.engine.activeStep, 0);
      expect(h.player.playing, 'c0/word');
      expect(h.engine.position, 0);
      expect(h.advances, isEmpty);
      // The replayed pass runs in full from here: nothing is left over from the first one.
      async.elapse(const Duration(milliseconds: passMs - 50));
      expect(h.heard, isEmpty);
      async.elapse(const Duration(milliseconds: 100));
      expect(h.heard, ['k0']);
    });
  });

  test('tap replay during a pause: restarts from the first line, pending advance cancelled', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: 9000));
      expect(h.engine.phase, ListenPhase.gap);
      h.engine.replay();
      expect(h.engine.activeStep, 0);
      expect(h.player.playing, 'c0/word');
      // The cancelled gap would have advanced at 10.1 s.
      async.elapse(const Duration(milliseconds: 2000));
      expect(h.advances, isEmpty);
      expect(h.engine.position, 0);
      // The replay counts again once it plays to the end (APP_SPEC 7).
      async.elapse(const Duration(milliseconds: passMs));
      expect(h.heard, ['k0', 'k0']);
    });
  });

  test('tap replay during a pause between lines: restarts from the first line', () {
    fakeAsync((async) {
      final h = Harness()..engine.start();
      async.elapse(const Duration(milliseconds: 5000));
      expect(h.engine.phase, ListenPhase.pause);
      h.engine.replay();
      expect(h.engine.activeStep, 0);
      async.elapse(const Duration(milliseconds: 2000));
      // The cancelled pause would have played the English sentence at 6.3 s.
      expect(h.player.played, isNot(contains('c0/en')));
      expect(h.engine.activeStep, 1);
    });
  });

  test('looped mode: repeats, heard on each full pass, position unchanged', () {
    fakeAsync((async) {
      final h = Harness(mode: CardMode.looped)..engine.start();
      async.elapse(const Duration(milliseconds: passMs + 50));
      expect(h.heard, ['k0']);
      async.elapse(const Duration(milliseconds: cardMs - passMs));
      expect(h.player.playing, 'c0/word', reason: 'the same card again');
      async.elapse(const Duration(milliseconds: cardMs * 2));
      expect(h.heard, ['k0', 'k0', 'k0']);
      expect(h.advances, isEmpty);
      expect(h.engine.position, 0);
    });
  });

  test('card mode switched mid-card: applies at the end of the pass, no double advance', () {
    fakeAsync((async) {
      final h = Harness(mode: CardMode.looped)..engine.start();
      async.elapse(const Duration(milliseconds: 3000));
      h.engine.cardMode = CardMode.continuous;
      async.elapse(const Duration(milliseconds: cardMs - 3000 + 50));
      expect(h.heard, ['k0']);
      expect(h.advances, [1]);
      // Switched back to looped mid-card: card 1 repeats instead of advancing.
      async.elapse(const Duration(milliseconds: 3000));
      h.engine.cardMode = CardMode.looped;
      async.elapse(const Duration(milliseconds: cardMs * 2));
      expect(h.advances, [1]);
      expect(h.heard, ['k0', 'k1', 'k1']);
    });
  });

  test('five swipes within 200 ms: exactly five advances, no audio left playing', () {
    fakeAsync((async) {
      final h = Harness(cards: 5)..engine.start();
      async.elapse(const Duration(milliseconds: 500));
      for (var i = 0; i < 5; i++) {
        h.engine.swipe();
        async.elapse(const Duration(milliseconds: 40));
      }
      expect(h.advances, [1, 2, 3, 4, 5]);
      expect(h.engine.phase, ListenPhase.end);
      expect(h.player.playing, isNull);
      final plays = h.player.played.length;
      async.elapse(const Duration(milliseconds: cardMs * 3));
      expect(h.advances, [1, 2, 3, 4, 5]);
      expect(h.player.played.length, plays, reason: 'no stale card went on playing');
      expect(h.player.playing, isNull);
      expect(h.heard, isEmpty);
    });
  });

  test('five swipes within 200 ms mid-deck: five advances, only the landing card plays', () {
    fakeAsync((async) {
      final h = Harness(cards: 8)..engine.start();
      async.elapse(const Duration(milliseconds: 1400));
      for (var i = 0; i < 5; i++) {
        h.engine.swipe();
        async.elapse(const Duration(milliseconds: 40));
      }
      expect(h.advances, [1, 2, 3, 4, 5]);
      // The landing card started at the fifth swipe, 40 ms ago.
      async.elapse(const Duration(milliseconds: cardMs - 40 - 50));
      expect(h.advances, [1, 2, 3, 4, 5]);
      expect(h.heard, ['k5']);
      async.elapse(const Duration(milliseconds: 100));
      expect(h.advances, [1, 2, 3, 4, 5, 6]);
    });
  });

  test('swipe on the last card lands on the end card', () {
    fakeAsync((async) {
      final h = Harness(position: 2)..engine.start();
      async.elapse(const Duration(milliseconds: 500));
      h.engine.swipe();
      expect(h.advances, [3]);
      expect(h.engine.position, 3);
      expect(h.engine.phase, ListenPhase.end);
      expect(h.player.playing, isNull);
      async.elapse(const Duration(milliseconds: cardMs * 2));
      expect(h.advances, [3]);
      expect(h.player.playing, isNull);
    });
  });

  test('the last card completing on its own lands on the end card', () {
    fakeAsync((async) {
      final h = Harness(position: 2)..engine.start();
      async.elapse(const Duration(milliseconds: cardMs + 50));
      expect(h.heard, ['k2']);
      expect(h.advances, [3]);
      expect(h.engine.phase, ListenPhase.end);
    });
  });

  group('beyond 11.6', () {
    test('the highlight follows the line that is playing', () {
      fakeAsync((async) {
        final h = Harness()..engine.start();
        final seen = <(int?, ListenPhase)>[];
        h.engine.addListener(() => seen.add((h.engine.activeStep, h.engine.phase)));
        async.elapse(const Duration(milliseconds: passMs + 100));
        expect(seen, [
          (0, ListenPhase.pause),
          (1, ListenPhase.playing),
          (1, ListenPhase.pause),
          (2, ListenPhase.playing),
          (2, ListenPhase.pause),
          (3, ListenPhase.playing),
          (3, ListenPhase.pause),
          (3, ListenPhase.gap),
        ]);
      });
    });

    test('pauses follow the line that was played; the German sentence pause is longest', () {
      fakeAsync((async) {
        final h = Harness()..engine.start();
        async.elapse(const Duration(milliseconds: 4900));
        expect(h.engine.phase, ListenPhase.pause);
        expect(h.engine.pausedAfter, LineRole.germanSentence);
        async.elapse(const Duration(milliseconds: 1350));
        expect(h.engine.activeStep, 2, reason: 'the 1.5 s pause is not over at 6.25 s');
        async.elapse(const Duration(milliseconds: 100));
        expect(h.engine.activeStep, 3);
      });
    });

    test('changed pauses apply from the next pause', () {
      fakeAsync((async) {
        final h = Harness()..engine.start();
        h.engine.pauses = const Pauses(afterWord: Duration(milliseconds: 100));
        async.elapse(const Duration(milliseconds: 1150));
        expect(h.player.playing, 'c0/translation');
      });
    });

    test('preloads the next clip, and the next card before the gap', () {
      fakeAsync((async) {
        final h = Harness()..engine.start();
        expect(h.player.preloaded, ['c0/translation']);
        async.elapse(const Duration(milliseconds: 7000));
        expect(h.player.preloaded.last, 'c1/word');
        async.elapse(const Duration(milliseconds: cardMs));
        expect(h.player.preloaded, contains('c1/translation'));
      });
    });

    test('looped mode preloads the same card again', () {
      fakeAsync((async) {
        final h = Harness(mode: CardMode.looped)..engine.start();
        async.elapse(const Duration(milliseconds: 7000));
        expect(h.player.preloaded.last, 'c0/word');
      });
    });

    test('stop and start (app backgrounded): the card restarts from its first line', () {
      fakeAsync((async) {
        final h = Harness()..engine.start();
        async.elapse(const Duration(milliseconds: 5000));
        h.engine.stop();
        expect(h.player.playing, isNull);
        expect(h.engine.phase, ListenPhase.idle);
        async.elapse(const Duration(milliseconds: cardMs * 2));
        expect(h.heard, isEmpty, reason: 'an interrupted card is not heard');
        expect(h.advances, isEmpty);
        h.engine.start();
        expect(h.player.playing, 'c0/word');
        expect(h.engine.position, 0);
      });
    });

    test('a clip that fails to play stops the card, not heard, and waits for a swipe', () {
      fakeAsync((async) {
        final h = Harness();
        h.player.failing.add('c0/de');
        h.engine.start();
        async.elapse(const Duration(milliseconds: cardMs * 2));
        expect(h.engine.phase, ListenPhase.failed);
        expect(h.engine.activeStep, 2);
        expect(h.heard, isEmpty);
        expect(h.advances, isEmpty);
        h.engine.swipe();
        expect(h.advances, [1]);
        expect(h.player.playing, 'c1/word');
      });
    });

    test('a failure reported after a swipe is ignored', () {
      fakeAsync((async) {
        final h = Harness();
        h.player.failing.add('c1/word');
        h.engine.start();
        async.elapse(const Duration(milliseconds: 500));
        h.engine.swipe();
        h.engine.swipe();
        async.flushMicrotasks();
        expect(h.engine.phase, ListenPhase.playing);
        expect(h.engine.position, 2);
      });
    });

    test('swipe and replay do nothing on the end card', () {
      fakeAsync((async) {
        final h = Harness(position: 3)..engine.start();
        expect(h.engine.phase, ListenPhase.end);
        h.engine.swipe();
        h.engine.replay();
        async.elapse(const Duration(milliseconds: cardMs));
        expect(h.advances, isEmpty);
        expect(h.player.played, isEmpty);
      });
    });

    test('dispose stops playback for good', () {
      fakeAsync((async) {
        final h = Harness()..engine.start();
        async.elapse(const Duration(milliseconds: 500));
        h.engine.dispose();
        async.elapse(const Duration(milliseconds: cardMs * 2));
        expect(h.player.playing, isNull);
        expect(h.advances, isEmpty);
        expect(h.heard, isEmpty);
      });
    });
  });
}
