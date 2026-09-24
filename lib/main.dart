import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'library/home.dart';
import 'library/library_controller.dart';
import 'packs/rescanner.dart';
import 'packs/saf_pack_storage.dart';
import 'playback/audio_host.dart';
import 'playback/just_audio_player.dart';
import 'session/deck_builder.dart';
import 'session/launch.dart';
import 'session/session_cards.dart';
import 'session/sessions.dart';
import 'settings/settings.dart';
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
      // Rescan timings, read on a device with `adb logcat | grep ohrwurm.rescan`.
      log: kDebugMode ? debugPrint : null,
    ),
    folderStore: PrefsRootFolderStore(),
    rejectionStore: PrefsRejectionStore(),
  );
  final settings = AppSettings(PrefsSettingsStore());
  await settings.load();
  final sessions = Sessions(
    db: database,
    deck: DeckBuilder(cards: database.cards, progress: database.progress),
    clips: StorageClipResolver(storage: storage, root: () => library.root),
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<LibraryController>.value(value: library),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        Provider<Sessions>.value(value: sessions),
        Provider<AudioHost>.value(value: PlatformAudioHost()),
        Provider<PlayerFactory>.value(value: (speed) => JustAudioClipPlayer()..speed = speed),
        Provider<PlayerDisposer>.value(
          value: (player) async {
            if (player is JustAudioClipPlayer) await player.dispose();
          },
        ),
      ],
      child: const OhrwurmApp(),
    ),
  );
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
