import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/session/launch.dart';
import 'package:ohrwurm/session/session_cards.dart';
import 'package:path/path.dart' as p;

import '../data/test_db.dart';
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

  test('a new session saves its resolved order at position 0', () async {
    final session = await kit.sessions.create(defaultOptions(['a1_k02']));
    final saved = (await db.session.load())!;
    expect(saved.cardOrder, session.cardOrder);
    expect(saved.cardOrder, ['a1_k02__der_freund', 'a1_k02__singen', 'a1_k02__heissen']);
    expect(saved.position, 0);
  });

  test('clips are the files in the pack folder, found with one listing per pack', () async {
    final session = await kit.sessions.create(defaultOptions(['a1_k02', 'a1_nb01']));
    kit.storage.listed.clear();
    final opened = await kit.sessions.open(session);
    // The root once, then each pack folder once.
    expect(kit.storage.listed, hasLength(3));
    final card = opened.cards.first;
    expect(
      card.clipUri(card.content.word),
      p.join(kit.folder.path, 'a1_k02', 'a1_k02__der_freund__word.ogg'),
    );
  });

  test('a clip missing since the scan gets a URI that fails to play', () async {
    File(p.join(kit.folder.path, 'a1_k02', 'a1_k02__singen__word.ogg')).deleteSync();
    final opened = await kit.sessions.open(await kit.sessions.create(defaultOptions(['a1_k02'])));
    final singen = opened.cards[1];
    expect(
      singen.clipUri(singen.content.word),
      missingClipUri('a1_k02', 'a1_k02__singen__word.ogg'),
    );
  });

  test('resume drops cards that are gone, and keeps the position on the same card', () async {
    await kit.sessions.create(defaultOptions(['a1_k02', 'a1_nb01']));
    // 8 cards: k02's 3, then nb01's 5. At nb01's fussball (index 5).
    await db.session.setPosition(5);
    await db.packs.setAvailable('a1_k02', false);
    final opened = await kit.sessions.open((await db.session.load())!);
    expect(opened.dropped, 3);
    expect(opened.mostlyGone, isFalse);
    expect(opened.cards.map((c) => c.row.cardId), [
      'a1_nb01__der_freund', 'a1_nb01__die_leute', 'a1_nb01__fussball', 'a1_nb01__gehen',
      'a1_nb01__in', //
    ]);
    expect(opened.position, 2);
    expect(opened.cards[opened.position].row.key, 'fussball');
    final saved = (await db.session.load())!;
    expect(saved.cardOrder, hasLength(5), reason: 'the saved order drops them too');
    expect(saved.position, 2);
  });

  test('more than half gone: the session is not resumed', () async {
    await kit.sessions.create(defaultOptions(['a1_k02', 'a1_nb01']));
    await db.packs.setAvailable('a1_nb01', false);
    final opened = await kit.sessions.open((await db.session.load())!);
    expect(opened.dropped, 5);
    expect(opened.mostlyGone, isTrue);
    expect((await db.session.load())!.cardOrder, hasLength(8), reason: 'left as it was');
  });

  test('restart keeps the order; reshuffle makes a new one; both from the first card', () async {
    final session = await kit.sessions.create(defaultOptions(['a1_k02', 'a1_nb01']));
    await db.session.setPosition(8);
    final restarted = await kit.sessions.restart(session);
    expect(restarted.cardOrder, session.cardOrder);
    expect(restarted.position, 0);
    await db.session.setPosition(8);
    final reshuffled = await kit.sessions.reshuffle(session);
    expect(reshuffled.cardOrder, unorderedEquals(session.cardOrder));
    expect(reshuffled.position, 0);
    expect(reshuffled.options.deckOrder, session.options.deckOrder, reason: 'same options');
  });
}
