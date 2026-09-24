// A8 (APP_SPEC 12, 15): record, play back, discard on leaving the card; permission refusal
// handled.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/library/home.dart';
import 'package:ohrwurm/mirror/mirror_controller.dart';
import 'package:ohrwurm/mirror/mirror_screen.dart';
import 'package:ohrwurm/mirror/recorder.dart';
import 'package:ohrwurm/session/copy.dart';
import 'package:ohrwurm/session/listen_screen.dart';

import '../data/test_db.dart';
import '../playback/fake_clip_player.dart';
import '../session/session_test_kit.dart';

SessionOptions mirrorOptions(List<String> packs, {Style style = Style.statement}) => SessionOptions(
  mode: SessionMode.mirror,
  packIds: packs,
  words: Words.all,
  focus: WordFocus.base,
  style: style,
  qaTranslate: QaTranslate.both,
  deckOrder: DeckOrder.sequential,
  cardMode: CardMode.looped,
  unheardFirst: false,
);

void main() {
  late AppDatabase db;
  late SessionKit kit;
  late FakeClipPlayer clips;
  late FakeClipPlayer mine;

  setUp(() async {
    db = await openTestDatabase(FakeClock());
    kit = await SessionKit.open(db);
    clips = FakeClipPlayer();
    mine = FakeClipPlayer();
  });

  tearDown(() async {
    kit.dispose();
    await db.close();
  });

  Future<MirrorController> show(WidgetTester tester, SessionOptions options) async {
    late MirrorController controller;
    await tester.runAsync(() async {
      final opened = await kit.sessions.open(await kit.sessions.create(options));
      controller = MirrorController(
        opened: opened,
        sessions: kit.sessions,
        progress: db.progress,
        cardDao: db.cards,
        player: clips,
        minePlayer: mine,
        recorder: kit.recorder,
        mic: kit.mic,
      );
    });
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      kit.wrap(MirrorScreen(controller: controller, packs: 'Freunde', onChangeSelection: () {})),
    );
    await tester.pump();
    return controller;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  test('boxes: the first two base statements, or the base question and answer', () async {
    final opened = await kit.sessions.open(await kit.sessions.create(mirrorOptions(['a1_k02'])));
    final freund = opened.cards.first.content;
    final statements = mirrorBoxes(freund, Style.statement);
    expect(statements, hasLength(1), reason: 'one box when only one base statement exists');
    expect(statements.single.pair.source.text, 'Mein Freund kommt aus Berlin.');
    expect(statements.single.label, isNull);
    final qa = mirrorBoxes(freund, Style.qa);
    expect(
      [for (final b in qa) b.pair.source.text],
      ['Hast du einen guten Freund?', 'Ja, mein Freund heißt Thomas.'],
    );
    expect([for (final b in qa) b.label], ['question', 'answer']);
  });

  testWidgets('no auto-play: the card waits; Play plays the German clip', (tester) async {
    final c = await show(tester, mirrorOptions(['a1_k02']));
    expect(find.text('der Freund'), findsOneWidget);
    expect(find.text('Mein Freund kommt aus Berlin.'), findsOneWidget);
    expect(find.text('My friend comes from Berlin.'), findsOneWidget);
    expect(find.byType(LineSegments), findsNothing);
    expect(kit.host.configured, [true], reason: 'play-and-record in Mirror');
    await tester.pump(const Duration(seconds: 20));
    expect(clips.played, isEmpty);
    expect(c.position, 0);

    await tester.tap(find.text(SessionCopy.play));
    await tester.pump();
    expect(clips.playing, endsWith('a1_k02__der_freund__ex1_src.ogg'));
    expect(tester.widget<HighlightLine>(find.byType(HighlightLine)).state, LineState.active);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.widget<HighlightLine>(find.byType(HighlightLine)).state, LineState.rest);
    await close(tester);
  });

  testWidgets('record, stop, play mine; the recording counts', (tester) async {
    final c = await show(tester, mirrorOptions(['a1_k02']));
    expect(find.text(SessionCopy.playMine), findsNothing);
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    expect(kit.mic.requests, 1, reason: 'asked on the first Record');
    expect(kit.recorder.recording, isTrue);
    expect(c.activity, BoxActivity.recording);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('${SessionCopy.stop} · 0:02'), findsOneWidget);

    await tester.tap(find.textContaining(SessionCopy.stop));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(kit.recorder.recording, isFalse);
    expect(find.text(SessionCopy.playMine), findsOneWidget);
    await tester.runAsync(() async {
      expect((await db.progress.get('der_freund'))!.timesRecorded, 1);
      expect((await db.progress.get('der_freund'))!.timesHeard, 0);
    });

    await tester.tap(find.text(SessionCopy.playMine));
    await tester.pump();
    expect(mine.playing, Uri.file('/tmp/mirror_0.m4a').toString());
    expect(clips.playing, isNull);
    await close(tester);
  });

  testWidgets('a new attempt replaces the last one', (tester) async {
    final c = await show(tester, mirrorOptions(['a1_k02']));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(SessionCopy.record));
      await tester.pump();
      await c.stopRecording();
      await tester.pump();
    }
    expect(kit.recorder.deleted, ['/tmp/mirror_0.m4a']);
    await tester.tap(find.text(SessionCopy.playMine));
    await tester.pump();
    expect(mine.playing, Uri.file('/tmp/mirror_1.m4a').toString());
    await close(tester);
  });

  testWidgets('Play while recording cancels the recording', (tester) async {
    final c = await show(tester, mirrorOptions(['a1_k02']));
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    await tester.tap(find.text(SessionCopy.play));
    await tester.pump();
    expect(kit.recorder.cancels, 1);
    expect(kit.recorder.recording, isFalse);
    expect(c.hasRecording(0), isFalse);
    expect(clips.playing, isNotNull);
    await close(tester);
  });

  testWidgets('Record while playing stops the clip', (tester) async {
    await show(tester, mirrorOptions(['a1_k02']));
    await tester.tap(find.text(SessionCopy.play));
    await tester.pump();
    expect(clips.playing, isNotNull);
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    expect(clips.playing, isNull);
    expect(kit.recorder.recording, isTrue);
    await close(tester);
  });

  testWidgets('swiping deletes the card\'s recordings and moves on', (tester) async {
    final c = await show(tester, mirrorOptions(['a1_k02']));
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    await c.stopRecording();
    await tester.pump();
    await tester.drag(find.text('der Freund'), const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.position, 1);
    expect(find.text('singen'), findsOneWidget);
    expect(kit.recorder.deleted, ['/tmp/mirror_0.m4a']);
    expect(find.text(SessionCopy.playMine), findsNothing);
    await tester.runAsync(() async {
      expect((await db.session.load())!.position, 1);
    });
    await close(tester);
  });

  testWidgets('leaving the screen deletes the recordings', (tester) async {
    final c = await show(tester, mirrorOptions(['a1_k02']));
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    await c.stopRecording();
    await close(tester);
    expect(kit.recorder.deleted, ['/tmp/mirror_0.m4a']);
  });

  testWidgets('microphone refused: Record explains why it can\'t work', (tester) async {
    kit.mic.answer = MicAccess.denied;
    await show(tester, mirrorOptions(['a1_k02']));
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    expect(find.text(SessionCopy.micDenied), findsOneWidget);
    expect(kit.recorder.recording, isFalse);
    expect(find.text(SessionCopy.openSettings), findsNothing);
    await close(tester);
  });

  testWidgets('refused for good: explains how to allow it, and opens the settings', (tester) async {
    kit.mic.answer = MicAccess.deniedForever;
    await show(tester, mirrorOptions(['a1_k02']));
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    expect(find.text(SessionCopy.micDeniedForever), findsOneWidget);
    await tester.tap(find.text(SessionCopy.openSettings));
    await tester.pump();
    expect(kit.mic.settingsOpened, 1);
    // Allowed now: the next Record works.
    kit.mic.answer = MicAccess.granted;
    await tester.tap(find.text(SessionCopy.record));
    await tester.pump();
    expect(kit.recorder.recording, isTrue);
    expect(find.text(SessionCopy.micDeniedForever), findsNothing);
    await close(tester);
  });

  testWidgets('Q&A: labelled Question and Answer boxes', (tester) async {
    await show(tester, mirrorOptions(['a1_k02'], style: Style.qa));
    expect(find.text(SessionCopy.question), findsOneWidget);
    expect(find.text(SessionCopy.answer), findsOneWidget);
    expect(find.text(SessionCopy.play), findsNWidgets(2));
    await close(tester);
  });

  testWidgets('setup: Mirror hides card mode and Q&A translation, and Start opens Mirror', (
    tester,
  ) async {
    kit.library.closeResult();
    await tester.runAsync(kit.setup.refresh);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(kit.wrap(const HomeScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text).first);
      await tester.tap(find.text(text).first);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    await tap('Freunde, Kollegen und ich');
    await tap('Q&A');
    expect(find.text('CARD MODE'), findsOneWidget);
    expect(find.text('Q&A TRANSLATION'), findsOneWidget);
    await tap('Mirror');
    expect(find.text('CARD MODE'), findsNothing);
    expect(find.text('Q&A TRANSLATION'), findsNothing);
    expect(find.text('FOCUS'), findsNothing);
    expect(find.text('1 pack · 2 cards'), findsOneWidget);
    await tap(SessionCopy.start);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MirrorScreen), findsOneWidget);
    expect(find.text(SessionCopy.question), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });
}
