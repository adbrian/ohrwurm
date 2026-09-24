import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/library/library_controller.dart';
import 'package:ohrwurm/packs/manifest.dart';
import 'package:ohrwurm/packs/pack_storage.dart';
import 'package:ohrwurm/packs/rescanner.dart';
import 'package:path/path.dart' as p;

import '../data/test_db.dart';
import '../packs/directory_pack_storage.dart';
import 'memory_folder_store.dart';

void main() {
  late AppDatabase database;
  late Directory root;
  late DirectoryPackStorage storage;
  late MemoryFolderStore store;

  setUp(() async {
    database = await openTestDatabase(FakeClock());
    root = copyFixturePacks();
    storage = DirectoryPackStorage();
    store = MemoryFolderStore();
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  LibraryController controller({ManifestChecker? check}) => LibraryController(
        storage: storage,
        packDao: database.packs,
        rescanner: Rescanner(
          storage: storage,
          packs: database.packs,
          schemaJson: schemaJson,
          check: check ?? checkManifestInIsolate,
        ),
        folderStore: store,
      );

  List<String> ids(LibraryController c) => [for (final p in c.packs) p.packId];

  test('first launch: no folder saved', () async {
    final c = controller();
    await c.start();
    expect(c.view, LibraryView.firstLaunch);
  });

  test('choosing a folder scans it, saves it and shows the result', () async {
    final c = controller();
    await c.start();
    storage.picked = root.path;
    await c.chooseFolder();

    expect(c.view, LibraryView.result);
    expect(store.uri, root.path);
    expect(ids(c), ['a1_k02', 'a1_nb01']);
    expect(c.report!.count(RescanOutcome.rejected), 1);
  });

  test('a cancelled picker changes nothing', () async {
    final c = controller();
    await c.start();
    await c.chooseFolder();
    expect(c.view, LibraryView.firstLaunch);
    expect(store.uri, isNull);
  });

  test('picking a pack folder says so and saves nothing', () async {
    final c = controller();
    await c.start();
    storage.picked = p.join(root.path, 'a1_k02');
    await c.chooseFolder();

    expect(c.view, LibraryView.looksLikePack);
    expect(store.uri, isNull);
    expect(await database.packs.listPacks(), isEmpty);
    c.closeLooksLikePack();
    expect(c.view, LibraryView.firstLaunch);
  });

  test('launch shows the library from the database, then rescans in the background', () async {
    Directory(p.join(root.path, 'a1_k03')).deleteSync(recursive: true);
    store.uri = root.path;
    await controller().start();

    final gate = Completer<void>();
    final c = controller(check: ({
      required schemaJson,
      required folderName,
      required manifestText,
      required clipNames,
    }) async {
      await gate.future;
      return checkManifest(
        schemaJson: schemaJson,
        folderName: folderName,
        manifestText: manifestText,
        clipNames: clipNames,
      );
    });
    final started = c.start();
    await pumpEventQueue();
    expect(c.view, LibraryView.library);
    expect(c.scanning, isTrue);
    expect(ids(c), ['a1_k02', 'a1_nb01']);

    // A second rescan while one runs does nothing.
    await c.rescan();
    expect(c.scanning, isTrue);

    gate.complete();
    await started;
    expect(c.scanning, isFalse);
    // Nothing changed, so the library stays.
    expect(c.view, LibraryView.library);
  });

  test('launch shows the result when something changed', () async {
    store.uri = root.path;
    await controller().start();
    Directory(p.join(root.path, 'a1_nb01')).deleteSync(recursive: true);

    final c = controller();
    await c.start();
    expect(c.view, LibraryView.result);
    // Still listed, unavailable.
    expect(ids(c), ['a1_k02', 'a1_nb01']);
    expect(c.packs.last.available, isFalse);
  });

  test('a saved folder with nothing loaded yet shows the first scan, not an empty library',
      () async {
    store.uri = root.path;
    final c = controller();
    final views = <LibraryView>[];
    c.addListener(() => views.add(c.view));
    await c.start();
    expect(views.first, LibraryView.firstScan);
  });

  test('the Rescan action always shows the result', () async {
    Directory(p.join(root.path, 'a1_k03')).deleteSync(recursive: true);
    store.uri = root.path;
    final c = controller();
    await c.start();
    c.closeResult();

    await c.rescan();
    expect(c.view, LibraryView.result);
    expect(c.report!.changed, isFalse);
  });

  test('a lost folder shows stale access, keeps the folder, and Try again recovers', () async {
    store.uri = root.path;
    await controller().start();
    final away = root.renameSync('${root.path}_away');

    final c = controller();
    await c.start();
    expect(c.view, LibraryView.stale);
    expect(c.access, RootAccess.missing);
    expect(store.uri, root.path);
    expect(ids(c), ['a1_k02', 'a1_nb01']);
    expect(c.packs.every((p) => p.available), isTrue);

    away.renameSync(root.path);
    await c.tryAgain();
    expect(c.view, isNot(LibraryView.stale));
  });

  test('lost permission shows stale access as denied', () async {
    store.uri = root.path;
    storage.access = RootAccess.denied;
    final c = controller();
    await c.start();
    expect(c.view, LibraryView.stale);
    expect(c.access, RootAccess.denied);
  });

  test('choosing another folder from stale access saves it', () async {
    store.uri = p.join(root.path, 'gone');
    final c = controller();
    await c.start();
    expect(c.view, LibraryView.stale);

    storage.picked = root.path;
    await c.chooseFolder();
    expect(store.uri, root.path);
    expect(c.view, LibraryView.result);
  });
}
