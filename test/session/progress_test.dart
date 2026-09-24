// A6 (APP_SPEC 7, 8, 15): progress per word key, shared across packs; pack progress; "also in".
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/session/launch.dart';
import 'package:ohrwurm/session/listen_controller.dart';
import 'package:ohrwurm/session/listen_screen.dart';
import 'package:ohrwurm/session/session_widgets.dart';

import '../data/test_db.dart';
import '../playback/fake_clip_player.dart';
import 'session_test_kit.dart';

void main() {
  late AppDatabase db;
  late SessionKit kit;

  setUp(() async {
    db = await openTestDatabase(FakeClock());
    kit = await SessionKit.open(db);
  });

  tearDown(() async {
    kit.dispose();
    await db.close();
  });

  /// Plays the first card of a session of [options] through one full pass, then closes it.
  Future<void> hearFirstCard(WidgetTester tester, SessionOptions options) async {
    late ListenController controller;
    await tester.runAsync(() async {
      final opened = await kit.sessions.open(await kit.sessions.create(options));
      controller = ListenController(
        opened: opened,
        sessions: kit.sessions,
        progress: db.progress,
        cardDao: db.cards,
        player: FakeClipPlayer(),
        pauses: kit.settings.pauses,
      );
    });
    await tester.pumpWidget(
      kit.wrap(ListenScreen(controller: controller, packs: '', onChangeSelection: () {})),
    );
    // Every fixture card's base statement recipe has four lines: 8.1 s at 1 s a clip.
    await tester.pump(const Duration(milliseconds: 8200));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    controller.dispose();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }

  testWidgets('hearing der_freund in a1_k02 counts in a1_nb01', (tester) async {
    await hearFirstCard(tester, defaultOptions(['a1_k02']));
    await tester.runAsync(() async {
      final progress = await db.progress.packProgress();
      expect(progress['a1_k02'], const PackProgress(heard: 1, total: 4));
      expect(progress['a1_nb01'], const PackProgress(heard: 1, total: 6));
      expect((await db.progress.get('der_freund'))!.timesHeard, 1);
    });
  });

  testWidgets('gehen and gehen_2 are tracked separately', (tester) async {
    final verbs = SessionOptions(
      mode: SessionMode.listen,
      packIds: const ['a1_nb01'],
      words: Words.verb,
      focus: WordFocus.base,
      style: Style.statement,
      qaTranslate: QaTranslate.both,
      deckOrder: DeckOrder.sequential,
      cardMode: CardMode.looped,
      unheardFirst: false,
    );
    await hearFirstCard(tester, verbs);
    await tester.runAsync(() async {
      expect((await db.progress.get('gehen'))!.timesHeard, 1);
      expect(await db.progress.get('gehen_2'), isNull);
      expect(await db.progress.heardKeys(), {'gehen'});
    });
  });

  testWidgets('a card left early is not heard', (tester) async {
    late ListenController controller;
    await tester.runAsync(() async {
      final opened = await kit.sessions.open(await kit.sessions.create(defaultOptions(['a1_k02'])));
      controller = ListenController(
        opened: opened,
        sessions: kit.sessions,
        progress: db.progress,
        cardDao: db.cards,
        player: FakeClipPlayer(),
        pauses: kit.settings.pauses,
      );
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      kit.wrap(ListenScreen(controller: controller, packs: '', onChangeSelection: () {})),
    );
    await tester.pump(const Duration(milliseconds: 7000));
    controller.swipe();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      expect(await db.progress.heardKeys(), isEmpty);
    });
  });

  test('also in: the other available packs with the same key', () async {
    expect(await db.cards.alsoIn('der_freund', 'a1_k02'), ['a1_nb01']);
    expect(await db.cards.alsoIn('der_freund', 'a1_nb01'), ['a1_k02']);
    expect(await db.cards.alsoIn('gehen', 'a1_nb01'), isEmpty);
    await db.packs.setAvailable('a1_nb01', false);
    expect(await db.cards.alsoIn('der_freund', 'a1_k02'), isEmpty);
  });

  test('also in shows short pack names; another level carries its level', () {
    expect(alsoInLabel(['a1_k02', 'a1_nb01'], 'a1_k01'), 'K2 · NB1');
    expect(alsoInLabel(['a2_k02'], 'a1_k01'), 'A2 K2');
  });

  test('a rescan that removes a pack keeps its progress (CLAUDE.md, rule 5)', () async {
    await db.progress.markHeard('fussball');
    await kit.library.rescan();
    await db.packs.setAvailable('a1_nb01', false);
    await kit.library.rescan();
    expect((await db.progress.get('fussball'))!.timesHeard, 1);
  });

  testWidgets('the Listen card shows also-in for a shared word', (tester) async {
    late ListenController controller;
    await tester.runAsync(() async {
      final opened = await kit.sessions.open(
        await kit.sessions.create(defaultOptions(['a1_nb01'])),
      );
      controller = ListenController(
        opened: opened,
        sessions: kit.sessions,
        progress: db.progress,
        cardDao: db.cards,
        player: FakeClipPlayer(),
        pauses: kit.settings.pauses,
      );
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      kit.wrap(ListenScreen(controller: controller, packs: '', onChangeSelection: () {})),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('also in K2'), findsOneWidget);
    controller.swipe();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('die Leute'), findsOneWidget);
    expect(find.textContaining('also in'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
