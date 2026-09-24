import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/library/home.dart';
import 'package:ohrwurm/library/widgets.dart';
import 'package:ohrwurm/session/copy.dart';
import 'package:ohrwurm/session/launch.dart';
import 'package:ohrwurm/session/listen_screen.dart';
import 'package:ohrwurm/session/setup_screen.dart';
import 'package:ohrwurm/theme/tokens.dart';
import 'package:path/path.dart' as p;

import '../data/test_db.dart';
import 'session_test_kit.dart';

void main() {
  late AppDatabase db;
  late SessionKit kit;

  setUp(() async {
    db = await openTestDatabase(FakeClock());
    kit = await SessionKit.open(db);
    kit.library.closeResult();
    await kit.setup.refresh();
  });

  tearDown(() async {
    kit.dispose();
    await db.close();
  });

  /// Lets database and file work finish, then redraws.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  Future<void> show(WidgetTester tester) async {
    // A phone-sized screen.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(kit.wrap(const HomeScreen()));
    await settle(tester);
  }

  Finder footer(String text) => find.text(text);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await settle(tester);
  }

  testWidgets('packs with their progress; Start waits for a pack', (tester) async {
    await show(tester);
    expect(find.text(SessionCopy.setupHeading), findsOneWidget);
    expect(find.text('Freunde, Kollegen und ich'), findsOneWidget);
    expect(find.text('0 / 4 heard'), findsOneWidget);
    expect(find.text('0 / 6 heard'), findsOneWidget);
    expect(footer('0 packs · 0 cards'), findsOneWidget);
    final start = find.widgetWithText(OutlinedButton, SessionCopy.start);
    expect(tester.widget<OutlinedButton>(start).onPressed, isNull);

    await tapText(tester, 'Freunde, Kollegen und ich');
    expect(footer('1 pack · 3 cards'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(start).onPressed, isNotNull);
    await tapText(tester, 'A1 · Notebook 1');
    expect(footer('2 packs · 8 cards'), findsOneWidget);
    expect(kit.setup.selected, ['a1_k02', 'a1_nb01'], reason: 'in selection order');
  });

  testWidgets('options change the live count; Focus shows only when it applies', (tester) async {
    await show(tester);
    await tapText(tester, 'Freunde, Kollegen und ich');
    await tapText(tester, 'A1 · Notebook 1');
    expect(find.text('FOCUS'), findsOneWidget);
    await tapText(tester, 'Verbs');
    expect(footer('2 packs · 3 cards'), findsOneWidget);
    expect(find.text('FOCUS'), findsNothing);
    await tapText(tester, 'All');
    expect(find.text('Q&A TRANSLATION'), findsNothing);
    await tapText(tester, 'Q&A');
    expect(find.text('Q&A TRANSLATION'), findsOneWidget);
    expect(footer('2 packs · 4 cards'), findsOneWidget);
  });

  testWidgets('options that exclude every card: 0 cards and which option to change', (
    tester,
  ) async {
    await show(tester);
    await tapText(tester, 'Freunde, Kollegen und ich');
    await tapText(tester, 'Plural');
    expect(footer('1 pack · 1 card'), findsOneWidget);
    await tapText(tester, 'Q&A');
    expect(footer('1 pack · 0 cards'), findsOneWidget);
    expect(find.textContaining('Try Focus: base.'), findsOneWidget);
    final start = find.widgetWithText(OutlinedButton, SessionCopy.start);
    expect(tester.widget<OutlinedButton>(start).onPressed, isNull);
  });

  testWidgets('the card limit steps from No limit, and truncates the count', (tester) async {
    await show(tester);
    await tapText(tester, 'Freunde, Kollegen und ich');
    await tapText(tester, 'A1 · Notebook 1');
    expect(find.text(SessionCopy.noLimit), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('More'));
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    expect(find.text('10 cards'), findsOneWidget);
    expect(footer('2 packs · 8 cards'), findsOneWidget);
    await tester.tap(find.byTooltip('Fewer'));
    await settle(tester);
    expect(find.text(SessionCopy.noLimit), findsOneWidget);
    expect(kit.setup.options.cardLimit, isNull);
  });

  testWidgets('a selected pack has an accent border; an unavailable one is not selectable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Directory(p.join(kit.folder.path, 'a1_nb01')).deleteSync(recursive: true);
      await kit.library.rescan();
    });
    kit.library.closeResult();
    await show(tester);
    await tapText(tester, 'Freunde, Kollegen und ich');
    Finder card(String heading) =>
        find.ancestor(of: find.text(heading), matching: find.byType(PackCard));
    expect(tester.widget<PackCard>(card('Freunde, Kollegen und ich')).selected, isTrue);
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    final border =
        tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: card('Freunde, Kollegen und ich'),
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect((border.border as Border).top.color, AppColors.accent);
    expect(border.color, AppColors.surface, reason: 'never a fill');
    await tapText(tester, 'A1 · Notebook 1');
    expect(kit.setup.selected, ['a1_k02']);
    expect(tester.widget<PackCard>(card('A1 · Notebook 1')).selected, isFalse);
  });

  testWidgets('Start opens the Listen card; back returns to setup with progress refreshed', (
    tester,
  ) async {
    await show(tester);
    await tapText(tester, 'Freunde, Kollegen und ich');
    await tester.tap(find.text(SessionCopy.start));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ListenScreen), findsOneWidget);
    expect(find.text('der Freund'), findsOneWidget);
    // A full pass of the first card.
    await tester.pump(const Duration(milliseconds: 8200));
    await settle(tester);
    await tester.tap(find.byTooltip(SessionCopy.back));
    await settle(tester);
    // The page transition.
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.byType(ListenScreen), findsNothing);
    expect(find.text('1 / 4 heard'), findsOneWidget);
    expect(kit.disposedPlayers, 1);
  });

  group('resume prompt (APP_SPEC 10.2, DESIGN 3)', () {
    Future<void> offer(WidgetTester tester, {List<String> packs = const ['a1_k02']}) async {
      await tester.runAsync(() async {
        await kit.sessions.create(defaultOptions(packs));
        await db.session.setPosition(1);
        kit.setup.offerResume(await db.session.load());
      });
    }

    testWidgets('shows the session and its position before anything else', (tester) async {
      await offer(tester);
      await show(tester);
      expect(find.text(SessionCopy.resumeKicker), findsOneWidget);
      expect(find.text('Freunde, Kollegen und ich'), findsOneWidget);
      expect(find.text('in order · loop · statements'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text(SessionCopy.setupHeading), findsNothing);
    });

    testWidgets('Resume plays from the saved position', (tester) async {
      await offer(tester);
      await show(tester);
      await tester.tap(find.text(SessionCopy.resume));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Card 2 of 3 · in order'), findsOneWidget);
      expect(find.text('singen'), findsOneWidget);
      expect(kit.player.playing, endsWith('a1_k02__singen__word.ogg'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('New session goes to setup, with the last selection', (tester) async {
      await offer(tester);
      await show(tester);
      await tester.tap(find.text(SessionCopy.newSession));
      await settle(tester);
      expect(find.text(SessionCopy.setupHeading), findsOneWidget);
      expect(footer('1 pack · 3 cards'), findsOneWidget);
    });

    testWidgets('most of the cards gone: explains, and offers only Choose packs', (tester) async {
      await offer(tester, packs: ['a1_k02', 'a1_nb01']);
      await tester.runAsync(() => db.packs.setAvailable('a1_nb01', false));
      await show(tester);
      expect(find.text(SessionCopy.mostlyGone), findsOneWidget);
      expect(find.text(SessionCopy.resume), findsNothing);
      await tester.tap(find.text(SessionCopy.choosePacks));
      await settle(tester);
      expect(find.text(SessionCopy.setupHeading), findsOneWidget);
    });
  });
}
