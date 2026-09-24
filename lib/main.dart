import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'library/home.dart';
import 'library/library_controller.dart';
import 'packs/rescanner.dart';
import 'packs/saf_pack_storage.dart';
import 'theme/app_theme.dart';

/// The manifest schema, bundled from `schema/` as it is: never copied or edited (CLAUDE.md,
/// rule 1).
const schemaAsset = 'schema/manifest.v2.schema.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final storage = SafPackStorage();
  final library = LibraryController(
    storage: storage,
    packDao: database.packs,
    rescanner: Rescanner(
      storage: storage,
      packs: database.packs,
      schemaJson: await rootBundle.loadString(schemaAsset),
    ),
    folderStore: PrefsRootFolderStore(),
  );
  runApp(MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: database),
      ChangeNotifierProvider<LibraryController>.value(value: library),
    ],
    child: const OhrwurmApp(),
  ));
  // The library shows from the database straight away; the rescan runs behind it.
  await library.start();
}

class OhrwurmApp extends StatelessWidget {
  const OhrwurmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ohrwurm',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
