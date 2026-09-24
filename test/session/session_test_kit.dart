import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/library/library_controller.dart';
import 'package:ohrwurm/mirror/recorder.dart';
import 'package:ohrwurm/packs/manifest.dart';
import 'package:ohrwurm/packs/rescanner.dart';
import 'package:ohrwurm/playback/audio_host.dart';
import 'package:ohrwurm/playback/clip_player.dart';
import 'package:ohrwurm/session/deck_builder.dart';
import 'package:ohrwurm/session/launch.dart';
import 'package:ohrwurm/session/session_cards.dart';
import 'package:ohrwurm/session/sessions.dart';
import 'package:ohrwurm/session/setup_controller.dart';
import 'package:ohrwurm/settings/settings.dart';
import 'package:ohrwurm/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../library/memory_folder_store.dart';
import '../packs/directory_pack_storage.dart';
import '../playback/fake_clip_player.dart';

/// An [AudioHost] that records what it's asked and lets a test send interruptions.
class FakeAudioHost implements AudioHost {
  final configured = <bool>[];
  bool screenOn = false;
  final _interruptions = StreamController<Interruption>.broadcast();

  void interrupt(Interruption event) => _interruptions.add(event);

  @override
  Future<void> configure({required bool record}) async => configured.add(record);

  @override
  Stream<Interruption> get interruptions => _interruptions.stream;

  @override
  Future<void> keepScreenOn(bool on) async => screenOn = on;
}

/// A [Recorder] that makes fake file paths and records what happened to them.
class FakeRecorder implements Recorder {
  int _next = 0;
  bool recording = false;
  final started = <String>[];
  final deleted = <String>[];
  int cancels = 0;

  @override
  Future<void> start() async {
    recording = true;
    started.add('/tmp/mirror_${_next++}.m4a');
  }

  @override
  Future<String?> stop() async {
    if (!recording) return null;
    recording = false;
    return started.last;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    recording = false;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<void> dispose() async {}
}

class FakeMic implements MicPermission {
  MicAccess answer = MicAccess.granted;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<MicAccess> request() async {
    requests++;
    return answer;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class MemorySettingsStore implements SettingsStore {
  final values = <String, Object>{};

  @override
  Future<Map<String, Object>> load() async => Map.of(values);

  @override
  Future<void> save(String key, Object value) async => values[key] = value;
}

/// The fixture packs, rescanned into [db] from a temporary copy, and everything a session screen
/// needs. Call [dispose] in tearDown.
class SessionKit {
  final AppDatabase db;
  final Directory folder;
  final DirectoryPackStorage storage;
  final LibraryController library;
  final Sessions sessions;
  final AppSettings settings = AppSettings(MemorySettingsStore());
  final host = FakeAudioHost();
  final recorder = FakeRecorder();
  final mic = FakeMic();
  late final SetupController setup = SetupController(
    library: library,
    deck: DeckBuilder(cards: db.cards, progress: db.progress),
    progress: db.progress,
  );
  final players = <FakeClipPlayer>[];
  int disposedPlayers = 0;

  SessionKit._(this.db, this.folder, this.storage, this.library, this.sessions);

  static Future<SessionKit> open(AppDatabase db) async {
    final folder = copyFixturePacks();
    final storage = DirectoryPackStorage(picked: folder.path);
    final library = LibraryController(
      storage: storage,
      packDao: db.packs,
      rescanner: Rescanner(
        storage: storage,
        packs: db.packs,
        schemaJson: schemaJson,
        check:
            ({
              required String schemaJson,
              required String folderName,
              required String manifestText,
              required Set<String> clipNames,
            }) async => checkManifest(
              schemaJson: schemaJson,
              folderName: folderName,
              manifestText: manifestText,
              clipNames: clipNames,
            ),
      ),
      folderStore: MemoryFolderStore(),
      rejectionStore: MemoryRejectionStore(),
    );
    await library.chooseFolder();
    final sessions = Sessions(
      db: db,
      deck: DeckBuilder(cards: db.cards, progress: db.progress),
      clips: StorageClipResolver(storage: storage, root: () => library.root),
    );
    return SessionKit._(db, folder, storage, library, sessions);
  }

  FakeClipPlayer get player => players.last;

  /// The app's providers around [child], with fake players and platform.
  Widget wrap(Widget child) => MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: db),
      ChangeNotifierProvider<LibraryController>.value(value: library),
      ChangeNotifierProvider<AppSettings>.value(value: settings),
      Provider<Sessions>.value(value: sessions),
      ChangeNotifierProvider<SetupController>.value(value: setup),
      Provider<AudioHost>.value(value: host),
      Provider<PlayerFactory>.value(
        value: (speed) {
          final p = FakeClipPlayer();
          players.add(p);
          return p;
        },
      ),
      Provider<RecorderFactory>.value(value: () => recorder),
      Provider<MicPermission>.value(value: mic),
      Provider<PlayerDisposer>.value(value: (ClipPlayer p) async => disposedPlayers++),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: child),
  );

  void dispose() => folder.deleteSync(recursive: true);
}
