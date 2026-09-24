import 'dart:isolate';

import '../data/models.dart';
import '../data/pack_dao.dart';
import 'manifest.dart';
import 'pack_display.dart';
import 'pack_storage.dart';

/// What happened to one subfolder, or one known pack, in a rescan (APP_SPEC 5.2).
enum RescanOutcome {
  added,
  updated,
  unchanged,

  /// Failed a check, or couldn't be saved. Nothing about it was loaded.
  rejected,

  /// A known pack whose folder is gone, or no longer holds a manifest.
  notFound,

  /// A subfolder without `manifest.json`: not a pack.
  skipped,
}

/// One row of the rescan result (DESIGN 2).
class RescanRow {
  final String folderName;
  final RescanOutcome outcome;

  /// What's known about the pack, for its display name: from the manifest when it got that far,
  /// else from the database for a known pack. Null for non-packs and unreadable new packs.
  final PackInput? pack;

  /// The number of cards loaded, for added and updated packs.
  final int? cardCount;

  /// Set when [outcome] is [RescanOutcome.rejected].
  final Rejection? rejection;

  /// The pack was in the database before this rescan, so it has rows (and maybe progress) that
  /// were kept.
  final bool known;

  const RescanRow({
    required this.folderName,
    required this.outcome,
    this.pack,
    this.cardCount,
    this.rejection,
    this.known = false,
  });
}

/// The result of [Rescanner.rescan].
sealed class RescanResult {
  const RescanResult();
}

/// The root folder can't be read (APP_SPEC 5.3). The database was not touched.
class RootUnavailable extends RescanResult {
  final RootAccess access;

  const RootUnavailable(this.access);
}

/// The root folder holds a `manifest.json`: it's a single pack, not the folder that holds packs
/// (APP_SPEC 5.1). The database was not touched.
class RootIsAPack extends RescanResult {
  const RootIsAPack();
}

class RescanReport extends RescanResult {
  /// Packs in the APP_SPEC 4.3 sort order, then the rest by folder name.
  final List<RescanRow> rows;

  /// Known packs that were available before this rescan and aren't any more.
  final Set<String> newlyUnavailable;

  const RescanReport(this.rows, {this.newlyUnavailable = const {}});

  /// Whether anything was added, updated or rejected, or a pack went missing.
  bool get changed => loadedOrLost || rows.any((r) => r.outcome == RescanOutcome.rejected);

  /// Whether anything was added or updated, or a pack went missing. With a rejection seen for
  /// the first time, these are the cases that show the result screen after an automatic rescan
  /// (STATUS, 2026-09-24).
  bool get loadedOrLost => rows.any((r) => switch (r.outcome) {
        RescanOutcome.added || RescanOutcome.updated => true,
        RescanOutcome.notFound => newlyUnavailable.contains(r.folderName),
        RescanOutcome.unchanged || RescanOutcome.rejected || RescanOutcome.skipped => false,
      });

  /// Each rejection as a [rejectionKey], to tell a new rejection from one already reported.
  Set<String> get rejections => {
        for (final r in rows)
          if (r.outcome == RescanOutcome.rejected) rejectionKey(r.folderName, r.rejection!),
      };

  int count(RescanOutcome outcome) => rows.where((r) => r.outcome == outcome).length;
}

/// A rejection's identity: the folder, and the reason as the result screen reports it. The same
/// pack rejected for a different reason (or a different number of missing clips) is a new
/// rejection. Folder names can't contain `/`, so [rejectedFolder] can split it again.
String rejectionKey(String folderName, Rejection why) {
  final reason = switch (why) {
    ClipsMissing(:final missing) => 'clips-missing ${missing.length}',
    ManifestUnreadable() => 'manifest-unreadable',
    SchemaInvalid() => 'schema-invalid',
    FolderMismatch(:final packId) => 'folder-mismatch $packId',
    UnplayableAudio(:final format) => 'unplayable-audio $format',
    SaveFailed() => 'save-failed',
  };
  return '$folderName/$reason';
}

/// The folder name in a [rejectionKey].
String rejectedFolder(String key) => key.substring(0, key.indexOf('/'));

/// Runs the checks of APP_SPEC 5.2 step 2 on one folder. Replaceable in tests.
typedef ManifestChecker = Future<ManifestCheck> Function({
  required String schemaJson,
  required String folderName,
  required String manifestText,
  required Set<String> clipNames,
});

/// Validating a chapter takes long enough to drop frames, so it runs in another isolate.
Future<ManifestCheck> checkManifestInIsolate({
  required String schemaJson,
  required String folderName,
  required String manifestText,
  required Set<String> clipNames,
}) =>
    Isolate.run(() => checkManifest(
          schemaJson: schemaJson,
          folderName: folderName,
          manifestText: manifestText,
          clipNames: clipNames,
        ));

/// Finds the packs in the root folder and reconciles them with the database (APP_SPEC 5.2).
///
/// Never touches `progress`. Each pack is written in its own transaction, so an interrupted
/// rescan leaves every pack fully old or fully new, and the next one completes the work.
class Rescanner {
  final PackStorage storage;
  final PackDao packs;
  final String schemaJson;
  final ManifestChecker check;

  /// Receives timing lines: one per folder, split by phase (list, read, check, save), and one
  /// for the whole rescan. Debug builds pass `debugPrint`, to measure rescans on a device.
  final void Function(String line)? log;

  Rescanner({
    required this.storage,
    required this.packs,
    required this.schemaJson,
    this.check = checkManifestInIsolate,
    this.log,
  });

  static const manifestName = 'manifest.json';

  Future<RescanResult> rescan(String root) async {
    final total = Stopwatch()..start();
    final result = await _rescan(root);
    log?.call('ohrwurm.rescan total ${total.elapsedMilliseconds} ms: ${result.runtimeType}');
    return result;
  }

  Future<RescanResult> _rescan(String root) async {
    final access = await storage.checkRoot(root);
    if (access != RootAccess.ok) return RootUnavailable(access);

    final List<StorageEntry> entries;
    try {
      entries = await storage.list(root);
    } catch (_) {
      return const RootUnavailable(RootAccess.denied);
    }
    if (entries.any((e) => !e.isDir && e.name == manifestName)) return const RootIsAPack();

    final known = {for (final p in await packs.listPacks()) p.packId: p};
    final found = <String>{};
    final rows = <RescanRow>[];

    for (final folder in entries.where((e) => e.isDir)) {
      final clock = Stopwatch()..start();
      final phases = _Phases();
      final row = await _scanFolder(folder, known[folder.name], phases);
      log?.call('ohrwurm.rescan ${folder.name} ${clock.elapsedMilliseconds} ms ($phases): '
          '${row?.outcome.name ?? 'notFound'}');
      if (row == null) continue;
      rows.add(row);
      if (row.outcome != RescanOutcome.rejected) found.add(folder.name);
    }

    final newlyUnavailable = <String>{};
    for (final pack in known.values) {
      if (found.contains(pack.packId)) continue;
      if (pack.available) newlyUnavailable.add(pack.packId);
      await packs.setAvailable(pack.packId, false);
      // A rejected known pack already has its row.
      if (rows.any((r) => r.folderName == pack.packId)) continue;
      rows.add(RescanRow(
        folderName: pack.packId,
        outcome: RescanOutcome.notFound,
        pack: _input(pack),
        known: true,
      ));
    }

    rows.sort(_compareRows);
    return RescanReport(rows, newlyUnavailable: newlyUnavailable);
  }

  /// Checks one subfolder and reconciles it. A known pack's folder without a manifest returns
  /// null: it's reported once, as not found, rather than also as skipped.
  Future<RescanRow?> _scanFolder(StorageEntry folder, Pack? knownPack, _Phases phases) async {
    final name = folder.name;
    RescanRow rejected(Rejection why, {PackInput? pack}) => RescanRow(
          folderName: name,
          outcome: RescanOutcome.rejected,
          pack: pack ?? _input(knownPack),
          rejection: why,
          known: knownPack != null,
        );

    final List<StorageEntry> files;
    try {
      files = await phases.time('list', () => storage.list(folder.uri));
    } catch (_) {
      return rejected(const ManifestUnreadable());
    }
    final manifestFile = files.where((f) => !f.isDir && f.name == manifestName).firstOrNull;
    if (manifestFile == null) {
      if (knownPack != null) return null;
      return RescanRow(folderName: name, outcome: RescanOutcome.skipped);
    }

    final ManifestCheck result;
    try {
      final text = await phases.time('read', () => storage.readText(manifestFile.uri));
      result = await phases.time(
        'check',
        () => check(
          schemaJson: schemaJson,
          folderName: name,
          manifestText: text,
          clipNames: {for (final f in files) if (!f.isDir) f.name},
        ),
      );
    } catch (_) {
      return rejected(const ManifestUnreadable());
    }

    final manifest = result.manifest;
    if (manifest == null) {
      final why = result.rejection!;
      // Past the folder check, the manifest names the pack; before it, it may not be this one.
      final named = why is UnplayableAudio || why is ClipsMissing;
      return rejected(why, pack: named ? result.pack : null);
    }

    final pack = manifest.pack;
    if (knownPack != null && knownPack.generatedAt == pack.generatedAt) {
      if (!knownPack.available) await packs.setAvailable(name, true);
      return RescanRow(
        folderName: name,
        outcome: RescanOutcome.unchanged,
        pack: pack,
        cardCount: knownPack.cardCount,
        known: true,
      );
    }

    try {
      await phases.time('save', () => packs.replacePack(pack, manifest.cards));
    } catch (_) {
      return rejected(const SaveFailed(), pack: pack);
    }
    return RescanRow(
      folderName: name,
      outcome: knownPack == null ? RescanOutcome.added : RescanOutcome.updated,
      pack: pack,
      cardCount: manifest.cards.length,
      known: knownPack != null,
    );
  }

  static PackInput? _input(Pack? p) => p == null ? null : packInputOf(p);
}

/// How long each phase of one folder's scan took, for the timing log: `list 12, read 3, …`.
class _Phases {
  final _ms = <String, int>{};

  Future<T> time<T>(String phase, Future<T> Function() work) async {
    final clock = Stopwatch()..start();
    try {
      return await work();
    } finally {
      _ms[phase] = clock.elapsedMilliseconds;
    }
  }

  @override
  String toString() => [for (final e in _ms.entries) '${e.key} ${e.value}'].join(', ');
}

/// APP_SPEC 4.3: level, then textbook before notebook, then number. Rows without a pack
/// come after, by folder name.
int _compareRows(RescanRow a, RescanRow b) {
  final pa = a.pack, pb = b.pack;
  if (pa == null || pb == null) {
    if (pa != null) return -1;
    if (pb != null) return 1;
    return a.folderName.compareTo(b.folderName);
  }
  return comparePacks(pa, pb, a.folderName, b.folderName);
}

/// The APP_SPEC 4.3 sort order, in Dart. Ties (which valid packs can't have) fall back to the
/// folder name so the order is stable.
int comparePacks(PackInput a, PackInput b, [String tieA = '', String tieB = '']) {
  int kindRank(String kind) => kind == 'textbook' ? 0 : 1;
  final byLevel = a.level.compareTo(b.level);
  if (byLevel != 0) return byLevel;
  final byKind = kindRank(a.kind).compareTo(kindRank(b.kind));
  if (byKind != 0) return byKind;
  final byNumber = a.number.compareTo(b.number);
  if (byNumber != 0) return byNumber;
  return tieA.compareTo(tieB);
}
