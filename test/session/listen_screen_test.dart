import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/playback/audio_host.dart';
import 'package:ohrwurm/session/copy.dart';
import 'package:ohrwurm/session/launch.dart';
import 'package:ohrwurm/session/listen_controller.dart';
import 'package:ohrwurm/session/listen_screen.dart';
import 'package:ohrwurm/session/session_cards.dart';

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

  /// Shows a Listen session of [options] with a fake player, 1 s per clip.
  Future<(ListenController, FakeClipPlayer)> show(
    WidgetTester tester, {
    SessionOptions? options,
    int position = 0,
  }) async {
    late OpenedSession opened;
    await tester.runAsync(() async {
      await kit.sessions.create(options ?? defaultOptions(['a1_k02']));
      if (position > 0) await db.session.setPosition(position);
      opened = await kit.sessions.open((await db.session.load())!);
    });
    final player = FakeClipPlayer();
    final controller = ListenController(
      opened: opened,
      sessions: kit.sessions,
      progress: db.progress,
      cardDao: db.cards,
      player: player,
      pauses: kit.settings.pauses,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      kit.wrap(
        ListenScreen(
          controller: controller,
          packs: 'Freunde, Kollegen und ich',
          onChangeSelection: () {},
        ),
      ),
    );
    // "Also in" is read from the database.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    return (controller, player);
  }

  LineState stateOf(WidgetTester tester, String text) => tester
      .widget<HighlightLine>(
        find.ancestor(of: find.text(text), matching: find.byType(HighlightLine)),
      )
      .state;

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the whole card, and plays it from the headword', (tester) async {
    final (_, player) = await show(tester);
    expect(find.text('der Freund'), findsOneWidget);
    expect(find.text('friend'), findsOneWidget);
    expect(find.text('die Freunde · die Freundin · female friend, girlfriend'), findsOneWidget);
    expect(find.text('Mein Freund kommt aus Berlin.'), findsOneWidget);
    expect(find.text('My friend comes from Berlin.'), findsOneWidget);
    expect(find.text('Card 1 of 3 · in order'), findsOneWidget);
    expect(find.text('also in NB1'), findsOneWidget);
    expect(find.text(SessionCopy.listening), findsOneWidget);
    expect(player.playing, endsWith('a1_k02__der_freund__word.ogg'));
    expect(find.byType(LineSegments), findsOneWidget);
    expect(tester.widget<LineSegments>(find.byType(LineSegments)).count, 4);
    await close(tester);
  });

  testWidgets('the highlight follows the line that is playing', (tester) async {
    await show(tester);
    expect(stateOf(tester, 'der Freund'), LineState.active);
    expect(stateOf(tester, 'friend'), LineState.upcoming);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(stateOf(tester, 'der Freund'), LineState.played);
    expect(stateOf(tester, 'friend'), LineState.active);
    // The long pause after the German sentence (3.8–4.8 s playing, then 1.5 s).
    await tester.pump(const Duration(milliseconds: 3100));
    expect(stateOf(tester, 'Mein Freund kommt aus Berlin.'), LineState.active);
    expect(find.text(SessionCopy.yourTurn), findsOneWidget);
    await close(tester);
  });

  testWidgets('a full pass counts the word heard; looped, the card repeats', (tester) async {
    final (controller, player) = await show(tester);
    await tester.pump(const Duration(milliseconds: 8200));
    expect(find.text(SessionCopy.looping), findsOneWidget);
    await tester.runAsync(() async {
      expect((await db.progress.get('der_freund'))!.timesHeard, 1);
    });
    await tester.pump(const Duration(milliseconds: 2000));
    expect(controller.position, 0);
    expect(player.playing, endsWith('a1_k02__der_freund__word.ogg'));
    await close(tester);
  });

  testWidgets('Next, and a swipe, move to the next card and save the position', (tester) async {
    final (controller, player) = await show(tester);
    await tester.tap(find.text(SessionCopy.next));
    await tester.pump();
    expect(find.text('Card 2 of 3 · in order'), findsOneWidget);
    expect(player.playing, endsWith('a1_k02__singen__word.ogg'));
    await tester.drag(find.text('singen'), const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.position, 2);
    expect(find.text('heißen'), findsOneWidget);
    await tester.runAsync(() async {
      expect((await db.session.load())!.position, 2);
    });
    await close(tester);
  });

  testWidgets('a short drag snaps back and stays on the card', (tester) async {
    final (controller, _) = await show(tester);
    await tester.drag(find.text('der Freund'), const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.position, 0);
    await close(tester);
  });

  testWidgets('tap replays from the first line, with Replaying… for about a second', (
    tester,
  ) async {
    final (controller, player) = await show(tester);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(player.playing, endsWith('translation.ogg'));
    await tester.tap(find.text('Mein Freund kommt aus Berlin.'));
    await tester.pump();
    expect(player.playing, endsWith('a1_k02__der_freund__word.ogg'));
    expect(find.text(SessionCopy.replaying), findsOneWidget);
    expect(controller.position, 0);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text(SessionCopy.replaying), findsNothing);
    await close(tester);
  });

  testWidgets('Loop toggles the card mode and saves it', (tester) async {
    final (controller, _) = await show(tester);
    await tester.tap(find.text(SessionCopy.loop));
    await tester.pump();
    expect(controller.cardMode, CardMode.continuous);
    await tester.runAsync(() async {
      expect((await db.session.load())!.options.cardMode, CardMode.continuous);
    });
    await tester.pump(const Duration(milliseconds: 8200));
    expect(find.text(SessionCopy.movingOn), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(controller.position, 1);
    await close(tester);
  });

  testWidgets('past the last card, the end card: Restart plays the same order again', (
    tester,
  ) async {
    final (controller, player) = await show(tester, position: 2);
    await tester.tap(find.text(SessionCopy.next));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(SessionCopy.endHeading), findsOneWidget);
    expect(find.text(SessionCopy.sessionDone), findsOneWidget);
    expect(find.text('3 cards'), findsOneWidget);
    expect(player.playing, isNull);
    await tester.runAsync(() async {
      expect((await db.session.load())!.position, 3);
    });
    await tester.tap(find.text(SessionCopy.restart));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(controller.position, 0);
    expect(find.text('der Freund'), findsOneWidget);
    expect(player.playing, endsWith('a1_k02__der_freund__word.ogg'));
    await close(tester);
  });

  testWidgets('backgrounded: playback stops; on return the card restarts from its first line', (
    tester,
  ) async {
    final (_, player) = await show(tester);
    await tester.pump(const Duration(milliseconds: 2000));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(player.playing, isNull);
    expect(kit.host.screenOn, isFalse);
    await tester.pump(const Duration(seconds: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player.playing, endsWith('a1_k02__der_freund__word.ogg'));
    expect(kit.host.screenOn, isTrue);
    await close(tester);
  });

  testWidgets('a call stops playback, and it restarts the card when the call ends', (tester) async {
    final (_, player) = await show(tester);
    kit.host.interrupt(Interruption.pauseBegin);
    await tester.pump();
    expect(player.playing, isNull);
    await tester.pump(const Duration(seconds: 20));
    expect(player.played.where((u) => u.contains('singen')), isEmpty);
    kit.host.interrupt(Interruption.pauseEnd);
    await tester.pump();
    expect(player.playing, endsWith('a1_k02__der_freund__word.ogg'));
    await close(tester);
  });

  testWidgets('keeps the screen on while open, per the setting', (tester) async {
    await show(tester);
    expect(kit.host.screenOn, isTrue);
    expect(kit.host.configured, [false]);
    await close(tester);
    expect(kit.host.screenOn, isFalse);
  });

  testWidgets('a clip that fails to play says so and waits for a swipe', (tester) async {
    late OpenedSession opened;
    await tester.runAsync(() async {
      opened = await kit.sessions.open(await kit.sessions.create(defaultOptions(['a1_k02'])));
    });
    final player = FakeClipPlayer()
      ..failing.add(opened.cards[0].clipUri(opened.cards[0].content.translation));
    final controller = ListenController(
      opened: opened,
      sessions: kit.sessions,
      progress: db.progress,
      cardDao: db.cards,
      player: player,
      pauses: kit.settings.pauses,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      kit.wrap(ListenScreen(controller: controller, packs: 'x', onChangeSelection: () {})),
    );
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text(SessionCopy.clipFailed), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(controller.position, 0);
    await close(tester);
  });
}
