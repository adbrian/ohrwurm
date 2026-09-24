import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/pack_dao.dart';
import '../packs/pack_storage.dart';
import '../packs/rescanner.dart';

/// Where the root folder's URI is kept between launches (APP_SPEC 6: `shared_preferences`).
abstract class RootFolderStore {
  Future<String?> load();
  Future<void> save(String uri);
}

class PrefsRootFolderStore implements RootFolderStore {
  static const _key = 'root_folder_uri';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> load() => _prefs.getString(_key);

  @override
  Future<void> save(String uri) => _prefs.setString(_key, uri);
}

/// The rejections the last rescan found, as [rejectionKey]s, kept between launches in
/// `shared_preferences` (APP_SPEC 6). An automatic rescan shows the result screen for a rejection
/// only the first time it's found, and the library can tell a rejected pack from a missing one
/// before the launch rescan ends (STATUS, 2026-09-24).
abstract class RejectionStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> keys);
}

class PrefsRejectionStore implements RejectionStore {
  static const _key = 'last_rejections';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<Set<String>> load() async => {...?await _prefs.getStringList(_key)};

  @override
  Future<void> save(Set<String> keys) => _prefs.setStringList(_key, keys.toList()..sort());
}

/// Which screen the library shows.
enum LibraryView {
  /// Reading the saved folder at launch.
  starting,

  /// No folder chosen yet (DESIGN 1).
  firstLaunch,

  /// A folder is saved but nothing has loaded from it yet, and the first rescan is running.
  firstScan,

  /// The pack list (DESIGN 4, read-only in A2).
  library,

  /// The rescan result (DESIGN 2).
  result,

  /// The saved folder can't be read (APP_SPEC 5.3). Never an empty library.
  stale,

  /// The chosen folder is a single pack, not the folder that holds packs (APP_SPEC 5.1).
  looksLikePack,
}

/// The pack folder, the packs in the database, and rescans (APP_SPEC 5).
///
/// The library shows from the database at once and rescans in the background; only one rescan
/// runs at a time (STATUS, 2026-09-24).
class LibraryController extends ChangeNotifier {
  final PackStorage storage;
  final PackDao packDao;
  final Rescanner rescanner;
  final RootFolderStore folderStore;
  final RejectionStore rejectionStore;

  LibraryController({
    required this.storage,
    required this.packDao,
    required this.rescanner,
    required this.folderStore,
    required this.rejectionStore,
  });

  LibraryView _view = LibraryView.starting;
  LibraryView get view => _view;

  /// The saved root folder's URI.
  String? _root;
  String? get root => _root;

  /// Every pack in the database, available or not, in the APP_SPEC 4.3 sort order.
  List<Pack> _packs = const [];
  List<Pack> get packs => _packs;

  /// The last rescan's report, shown on [LibraryView.result].
  RescanReport? _report;
  RescanReport? get report => _report;

  /// Why the root can't be read, on [LibraryView.stale].
  RootAccess? _access;
  RootAccess? get access => _access;

  /// The last rescan's rejections, as [rejectionKey]s.
  Set<String> _rejections = const {};

  /// Whether [pack] is unavailable because the last rescan rejected it (tag *Not loaded*),
  /// rather than because its folder is gone (*Not found*).
  bool wasRejected(Pack pack) =>
      !pack.available && _rejections.any((k) => rejectedFolder(k) == pack.packId);

  bool _scanning = false;
  bool get scanning => _scanning;

  /// The screen to return to from [LibraryView.looksLikePack].
  LibraryView _beforeLooksLikePack = LibraryView.firstLaunch;

  /// A readable form of [root], for display.
  String? get location => _root == null ? null : storage.describe(_root!);

  /// Loads the saved folder and the library, then rescans in the background.
  Future<void> start() async {
    _root = await folderStore.load();
    if (_root == null) {
      _show(LibraryView.firstLaunch);
      return;
    }
    _packs = await packDao.listPacks();
    _rejections = await rejectionStore.load();
    _show(_packs.isEmpty ? LibraryView.firstScan : LibraryView.library);
    await _rescan(_root!, alwaysShowResult: false);
  }

  /// Asks for a folder, then scans it. The folder is saved only once it has been scanned as a
  /// folder of packs.
  Future<void> chooseFolder() async {
    if (_scanning) return;
    final picked = await storage.pickFolder(initial: _root);
    if (picked == null) return;
    await _rescan(picked, alwaysShowResult: true);
  }

  /// The Rescan action: the result always shows.
  Future<void> rescan() async {
    final root = _root;
    if (root == null) return;
    await _rescan(root, alwaysShowResult: true);
  }

  /// *Try again* on the stale-access screen: the saved folder is kept (APP_SPEC 5.3).
  Future<void> tryAgain() async {
    final root = _root;
    if (root == null) return;
    await _rescan(root, alwaysShowResult: false);
  }

  /// Leaves the result screen for the library.
  void closeResult() => _show(LibraryView.library);

  /// Leaves the "looks like one pack" screen without choosing again.
  void closeLooksLikePack() => _show(_beforeLooksLikePack);

  Future<void> _rescan(String folder, {required bool alwaysShowResult}) async {
    if (_scanning) return;
    _scanning = true;
    notifyListeners();
    try {
      final result = await rescanner.rescan(folder);
      switch (result) {
        case RootIsAPack():
          if (_view != LibraryView.looksLikePack) _beforeLooksLikePack = _view;
          _show(LibraryView.looksLikePack);
        case RootUnavailable(:final access):
          await _adopt(folder);
          _access = access;
          _show(LibraryView.stale);
        case RescanReport():
          await _adopt(folder);
          _packs = await packDao.listPacks();
          _report = result;
          final rejections = result.rejections;
          // A rejection counts as a change only the first time it's found (STATUS, 2026-09-24).
          final newRejection = rejections.difference(_rejections).isNotEmpty;
          if (!setEquals(rejections, _rejections)) {
            _rejections = rejections;
            await rejectionStore.save(rejections);
          }
          final show = alwaysShowResult || result.loadedOrLost || newRejection;
          _show(show ? LibraryView.result : LibraryView.library);
      }
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<void> _adopt(String folder) async {
    if (folder == _root) return;
    _root = folder;
    await folderStore.save(folder);
  }

  void _show(LibraryView view) {
    _view = view;
    notifyListeners();
  }
}
