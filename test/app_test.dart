import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/library/copy.dart';
import 'package:ohrwurm/library/library_controller.dart';
import 'package:ohrwurm/main.dart';
import 'package:ohrwurm/packs/rescanner.dart';
import 'package:ohrwurm/theme/tokens.dart';
import 'package:provider/provider.dart';

import 'data/test_db.dart';
import 'library/memory_folder_store.dart';
import 'packs/directory_pack_storage.dart';

void main() {
  late AppDatabase database;

  setUp(() async => database = await openTestDatabase(FakeClock()));

  tearDown(() => database.close());

  testWidgets('app starts on the dark theme, at first launch', (tester) async {
    final storage = DirectoryPackStorage();
    final library = LibraryController(
      storage: storage,
      packDao: database.packs,
      rescanner: Rescanner(storage: storage, packs: database.packs, schemaJson: schemaJson),
      folderStore: MemoryFolderStore(),
    );
    await tester.runAsync(library.start);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: library, child: const OhrwurmApp()),
    );

    final heading = find.text(Copy.firstLaunchHeading);
    expect(heading, findsOneWidget);
    final theme = Theme.of(tester.element(heading));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.bg);
  });
}
