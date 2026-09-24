import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/library/copy.dart';
import 'package:ohrwurm/library/home.dart';
import 'package:ohrwurm/library/library_controller.dart';
import 'package:ohrwurm/packs/manifest.dart';
import 'package:ohrwurm/packs/rescanner.dart';
import 'package:ohrwurm/theme/app_theme.dart';
import 'package:ohrwurm/theme/tokens.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../data/test_db.dart';
import '../packs/directory_pack_storage.dart';
import 'memory_folder_store.dart';

void main() {
  late AppDatabase database;
  late Directory root;
  late DirectoryPackStorage storage;
  late MemoryFolderStore store;
  late LibraryController library;

  setUp(() async {
    database = await openTestDatabase(FakeClock());
    root = copyFixturePacks();
    storage = DirectoryPackStorage();
    store = MemoryFolderStore();
    library = LibraryController(
      storage: storage,
      packDao: database.packs,
      rescanner: Rescanner(storage: storage, packs: database.packs, schemaJson: schemaJson),
      folderStore: store,
    );
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: library,
      child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
    ));
  }

  /// Runs controller work that does real file and isolate I/O, then redraws.
  Future<void> run(WidgetTester tester, Future<void> Function() work) async {
    await tester.runAsync(work);
    await tester.pump();
  }

  testWidgets('first launch asks for the folder', (tester) async {
    await run(tester, library.start);
    await show(tester);
    expect(find.text(Copy.firstLaunchHeading), findsOneWidget);
    for (final step in Copy.firstLaunchSteps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.widgetWithText(OutlinedButton, Copy.chooseFolder), findsOneWidget);
  });

  testWidgets('the fixture folder: two loaded, a1_k03 rejected whole, notes skipped',
      (tester) async {
    await run(tester, library.start);
    storage.picked = root.path;
    // Not a tap: the scan does real file and isolate I/O, which needs runAsync.
    await run(tester, library.chooseFolder);
    await show(tester);

    expect(find.text(root.path), findsOneWidget);
    expect(find.text('Freunde, Kollegen und ich'), findsOneWidget);
    expect(find.text('added · 4 words'), findsOneWidget);
    expect(find.text('A1 · Notebook 1'), findsOneWidget);
    expect(find.text('added · 6 words'), findsOneWidget);
    expect(find.text('In der Stadt'), findsOneWidget);
    expect(find.text('not loaded · 1 audio file missing'), findsOneWidget);
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('no manifest · skipped'), findsOneWidget);
    expect(find.text("One pack wasn't loaded. The rest are ready."), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, Copy.rescan), findsOneWidget);
  });

  testWidgets('the library lists packs in order, the missing one dimmed and tagged',
      (tester) async {
    store.uri = root.path;
    await run(tester, library.start);
    Directory(p.join(root.path, 'a1_nb01')).deleteSync(recursive: true);
    await run(tester, library.rescan);
    library.closeResult();
    await show(tester);

    expect(find.text(Copy.libraryHeading), findsOneWidget);
    final k02 = tester.getTopLeft(find.text('Freunde, Kollegen und ich'));
    final nb01 = tester.getTopLeft(find.text('A1 · Notebook 1'));
    expect(k02.dy, lessThan(nb01.dy));
    expect(find.text('A1 · Chapter 2 · 4 words'), findsOneWidget);
    // No title: the label is the heading and isn't repeated.
    expect(find.text('6 words'), findsOneWidget);
    expect(find.text(Copy.notFound), findsOneWidget);
    expect(tester.widget<Text>(find.text('A1 · Notebook 1')).style!.color, AppColors.neutral600);
    expect(find.text('In der Stadt'), findsNothing);
  });

  testWidgets('a lost folder offers Try again and never an empty library', (tester) async {
    store.uri = p.join(root.path, 'moved');
    await run(tester, library.start);
    await show(tester);

    expect(find.text(Copy.staleHeading), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, Copy.tryAgain), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, Copy.chooseFolder), findsOneWidget);
    expect(find.text(Copy.libraryHeading), findsNothing);
  });

  testWidgets('a pack folder picked as the root is explained', (tester) async {
    await run(tester, library.start);
    storage.picked = p.join(root.path, 'a1_k02');
    await run(tester, library.chooseFolder);
    await show(tester);
    expect(find.text(Copy.onePackHeading), findsOneWidget);
    await tester.tap(find.byTooltip(Copy.back));
    await tester.pump();
    expect(find.text(Copy.firstLaunchHeading), findsOneWidget);
  });

  group('wording', () {
    RescanRow rejected(Rejection why, {bool known = false}) => RescanRow(
          folderName: 'a1_k02',
          outcome: RescanOutcome.rejected,
          rejection: why,
          known: known,
        );

    test('rejection reasons', () {
      expect(rowDetail(rejected(const ClipsMissing(['a', 'b']))),
          'not loaded · 2 audio files missing');
      expect(rowDetail(rejected(const ManifestUnreadable())),
          "not loaded · manifest couldn't be read");
      expect(rowDetail(rejected(const SchemaInvalid(['x']))),
          "not loaded · manifest doesn't match the pack format");
      expect(rowDetail(rejected(const FolderMismatch('a1_k05'))),
          "not loaded · folder name doesn't match the pack (a1_k05)");
      expect(rowDetail(rejected(const UnplayableAudio('mp3'))),
          "not loaded · audio format mp3 isn't supported");
      expect(rowDetail(rejected(const ManifestUnreadable(), known: true)),
          "not loaded · manifest couldn't be read · progress kept");
      expect(
        rowDetail(const RescanRow(
          folderName: 'a1_nb01',
          outcome: RescanOutcome.notFound,
          known: true,
        )),
        'not found · progress kept',
      );
    });

    RescanRow ok(RescanOutcome outcome) =>
        RescanRow(folderName: 'x', outcome: outcome, cardCount: 1);

    test('verdicts', () {
      expect(verdict(RescanReport([ok(RescanOutcome.added), ok(RescanOutcome.unchanged)])),
          (fine: true, message: '2 packs ready.'));
      expect(verdict(RescanReport([ok(RescanOutcome.unchanged)])),
          (fine: true, message: 'One pack ready.'));
      expect(
        verdict(RescanReport([ok(RescanOutcome.unchanged), rejected(const SaveFailed())])),
        (fine: false, message: "One pack wasn't loaded. Nothing else changed."),
      );
      expect(
        verdict(RescanReport([
          ok(RescanOutcome.added),
          rejected(const SaveFailed()),
          rejected(const SaveFailed()),
        ])),
        (fine: false, message: "2 packs weren't loaded. The rest are ready."),
      );
      expect(verdict(const RescanReport([])).fine, isFalse);
    });
  });
}
