/// Wording for the A2 screens. Where DESIGN gives the words they're used as written; the rest is
/// proposed in DESIGN's voice, describing failures by what was protected, for Ian's review
/// (STATUS, 2026-09-24).
library;

import '../packs/manifest.dart';
import '../packs/pack_display.dart';
import '../packs/rescanner.dart';

/// `One` for 1, else the digits: *One pack wasn't loaded*, *2 packs ready*.
String _count(int n, String noun) => n == 1 ? 'One $noun' : '$n ${noun}s';

/// The detail line of a rescan row (DESIGN 2).
String rowDetail(RescanRow row) {
  final detail = switch (row.outcome) {
    RescanOutcome.added => 'added · ${wordCount(row.cardCount!)}',
    RescanOutcome.updated => 'updated · ${wordCount(row.cardCount!)}',
    RescanOutcome.unchanged => 'unchanged',
    RescanOutcome.rejected => 'not loaded · ${rejectionReason(row.rejection!)}',
    RescanOutcome.notFound => 'not found',
    RescanOutcome.skipped => 'no manifest · skipped',
  };
  final kept = row.known &&
      (row.outcome == RescanOutcome.rejected || row.outcome == RescanOutcome.notFound);
  return kept ? '$detail · progress kept' : detail;
}

String rejectionReason(Rejection why) => switch (why) {
      ClipsMissing(:final missing) =>
        missing.length == 1 ? '1 audio file missing' : '${missing.length} audio files missing',
      ManifestUnreadable() => "manifest couldn't be read",
      SchemaInvalid() => "manifest doesn't match the pack format",
      FolderMismatch(:final packId) => "folder name doesn't match the pack ($packId)",
      UnplayableAudio(:final format) => "audio format $format isn't supported",
      SaveFailed() => "couldn't be saved on this phone",
    };

/// The row's name: the pack's heading when known, else the folder name.
String rowName(RescanRow row) => row.pack == null ? row.folderName : packHeading(row.pack!);

/// The verdict panel's message (DESIGN 2), and whether everything was fine.
({bool fine, String message}) verdict(RescanReport report) {
  final rejected = report.count(RescanOutcome.rejected);
  final ready = report.count(RescanOutcome.added) +
      report.count(RescanOutcome.updated) +
      report.count(RescanOutcome.unchanged);
  if (rejected > 0) {
    final notLoaded = rejected == 1 ? "One pack wasn't loaded." : "$rejected packs weren't loaded.";
    // DESIGN's *Nothing else changed* would be untrue when the same rescan loaded packs.
    final loaded = report.count(RescanOutcome.added) + report.count(RescanOutcome.updated);
    return (
      fine: false,
      message: loaded == 0 ? '$notLoaded Nothing else changed.' : '$notLoaded The rest are ready.',
    );
  }
  if (ready == 0) {
    return (
      fine: false,
      message: 'No packs in this folder yet. Copy your pack folders into it, then rescan.',
    );
  }
  return (fine: true, message: '${_count(ready, 'pack')} ready.');
}

abstract final class Copy {
  // First launch (DESIGN 1).
  static const firstLaunchHeading = "Let's get your ears working.";
  static const firstLaunchBody = 'You see a word and its sentences and hear each one read aloud. '
      'Read along, then swipe to the next. No typing, no network.';
  static const firstLaunchSteps = [
    'Make packs on your computer.',
    'Copy the pack folders onto this phone.',
    'Show Ohrwurm where you put them.',
  ];
  static const chooseFolder = 'Choose folder';

  // Rescan result (DESIGN 2).
  static const choosePacks = 'Choose packs';
  static const rescan = 'Rescan';

  // Library (DESIGN 4, read-only).
  static const libraryHeading = 'Your packs';
  static const notFound = 'Not found';
  static const checking = 'Checking the folder…';
  static const emptyLibrary = 'No packs in this folder yet. Copy your pack folders into it, '
      'then rescan.';

  // First scan of a newly saved folder.
  static const firstScan = 'Reading your packs…';

  // Stale access (APP_SPEC 5.3).
  static const staleHeading = "Can't reach your pack folder";
  static const staleKept = 'Nothing has been deleted. Your packs and progress are kept on this '
      'phone.';
  static const staleMissing = "The folder may have moved, or the phone's storage may not be "
      'ready yet. That can happen just after it starts up.';
  static const staleDenied = 'Ohrwurm no longer has permission to read it.';
  static const tryAgain = 'Try again';

  // Picked a pack folder instead of the root (APP_SPEC 5.1).
  static const onePackHeading = 'That looks like one pack';
  static const onePackBody = 'The folder you picked has a manifest in it, so it holds a single '
      'pack. Choose the folder your pack folders are in, usually the one above it.';
  static const back = 'Back';
}
