# A0 — Storage and playback spike: findings

Step A0 of the Build Plan (APP_SPEC 5.1, 15). Spike code: `spike/a0_storage/` on branch `spike/a0`
(application id `io.github.adbrian.ohrwurm.spike`). Run on 2026-09-23.

## Result

**Recommendation: (a) read in place**, using the Storage Access Framework through two maintained
packages, **`saf_util` 3.1.0** (pick folder, persisted permission, list) and **`saf_stream` 4.0.1**
(read bytes). No Kotlin platform channel was needed. `file_picker` is ruled out.

The A0 bar — pick folder → read manifest → play an `.ogg` → relaunch → play again without
re-picking — **passes on both devices**, and also survives reboot and app update.

## Devices

| | POCO F1 | Emulator |
|---|---|---|
| Android | 10 (API 29), MIUI `QKQ1.190828.002` | 14 (API 34), `google_apis` x86_64, KVM |
| Build | release APK, `minSdk 29`, `targetSdk 36` | same APK |
| Packs | `Download/ohrwurm-packs/`: `a1_k02`, `a1_k03`, `a1_nb01`, `notes`, `b2_k99` | same |

`b2_k99` is a stress pack from `spike/make_stress_pack.py`: 125 cards, 1,500 clips, 13.6 MB,
schema-valid. It stands in for a real chapter.

## Device test script

| Step | POCO F1 (Android 10) | Emulator (Android 14) |
|---|---|---|
| 1. Pick folder (SAF) | Pass. No "Allow access?" dialog (that arrived in Android 11) | Pass. "Allow access?" dialog, then granted |
| Picker opens at `Download/ohrwurm-packs` via `initialUri` | Yes | Yes |
| List packs, read manifests | Pass. `notes` skipped, `a1_k03` reports its 1 missing clip | Pass, same |
| Play `.ogg` from `content://` URI (a) | Pass | Pass |
| Copy pack to app-private storage, play from file (b) | Pass | Pass |
| 2. Force-stop, cold relaunch, play again | Pass, no re-pick | Pass, no re-pick |
| 3. Reboot, relaunch, play again | Pass | Pass (see "Activity recreation") |
| 4. Install over existing app (update), play again | Pass | Pass |
| 5a. Pack folder renamed away | `list()` returns **0 entries, no error**; `hasPersistedPermission` still true; root `stat` → missing | Same |
| 5a. Renamed back | Access returns with no re-pick | Same |
| 5b. Permission released | `hasPersistedPermission` false; listing throws Permission Denial | Same |
| `file_picker.getDirectoryPath` control | Path returned; **listing and reading both denied** | Path returned; listing works, **reading `manifest.json` denied** |

`just_audio`'s `play()` completed at the end of the clip in every run (`processingState`
`completed`), which is the contract `ClipPlayer.play` needs (APP_SPEC 11.1).

Audible output was not checked by ear during the automated runs; completion after the clip's
duration shows the Opus clips were decoded and played through.

## Timings

Release build. "Warm" = app already run since boot; "after reboot" = first run after a reboot.

| Measurement | POCO F1 | Emulator |
|---|---|---|
| List root folder | 13–35 ms | 8–20 ms (189 ms after reboot) |
| List `b2_k99`, 1,501 entries, **one query** | 221 ms (314 ms after reboot) | 712 ms (3,666 ms after reboot) |
| Read `b2_k99/manifest.json` | 7 ms | 25 ms |
| Check 1,500 referenced clips against the listing (in Dart) | < 1 ms | < 1 ms |
| Look up clips **one at a time** (`child()`), per clip | 85–153 ms | 196 ms |
| … extrapolated to 1,500 clips | **2–4 minutes** | **~5 minutes** |
| Clip load (`setAudioSource`), (a) `content://` | 111–169 ms; **450–550 ms for the first clip after install or reboot** | 62–148 ms |
| Clip load, (b) app-private file | 73–130 ms | 46–55 ms |
| Copy `b2_k99` into app-private storage (b) | 6.9 s (10.6 s after reboot) | 10.2 s |

## Trade-offs

**(a) Read in place — recommended**

- No duplicated storage.
- A rescan of a 1,500-clip pack costs one listing plus one manifest read: well under a second on the
  POCO, a few seconds cold on the emulator.
- Clip load is 40–80 ms slower than from a local file. Every clip is followed by a pause of at
  least 800 ms (11.4), so the difference is small, but it lands inside `play()`. The first clip
  after install or reboot takes about half a second.
- Playback depends on the folder staying put. If files are removed from under a running session,
  the next clip fails mid-session — the case 5.2 avoids by rejecting packs at scan time. A2/A4 need
  a behaviour for "clip failed to load" during a session; the spec doesn't define one yet.

**(b) Copy on import**

- Every pack is stored twice: 13.6 MB for the 1,500-clip stress pack (tones; real speech clips
  will differ).
- Import is slow: 7–11 s per chapter, so a first scan of a whole textbook would take minutes and
  need progress UI.
- Playback is independent of the folder once copied, and loads slightly faster.
- It still needs SAF (and the same permission handling) to read the folder for import, so it
  removes none of (a)'s storage work — it only adds to it.

## Findings that affect later steps

1. **Check clip existence with one listing per pack, never per-file lookups.** A per-file check
   takes minutes per chapter. List the pack folder once and compare names with the manifest's
   references (A2).
2. **A moved or deleted folder looks like an empty folder.** `list()` of a tree whose folder is gone
   returns `[]` without error, and the persisted permission still reports as held. Detecting stale
   access (5.3) must `stat` the root folder itself, not trust a successful listing — otherwise the
   app shows the empty library the spec forbids (A2).
3. **Storage can look missing briefly after boot.** On the POCO, `Download/ohrwurm-packs` was
   invisible to a shell for a few seconds after `boot_completed`, then reappeared intact. A missing
   root should offer *Try again* and keep the saved folder rather than discard it at once (A2).
4. **Save the tree URI, not the document URI.** `saf_util.pickDirectory` returns
   `…/tree/<id>/document/<id>`. The grant is held on `…/tree/<id>`; `releasePersistedPermission`
   rejects the longer form. Store the tree URI in `shared_preferences` (A2).
5. **Activity recreation loses in-flight work.** On the emulator, just after reboot, the system
   applied a resource overlay (`CONFIG_ASSETS_PATHS`, which apps cannot opt out of) and recreated
   the activity mid-run. Same process, but the app's launch check ran again and the running checks
   were lost. (By Flutter's default, a recreated `FlutterActivity` builds a new engine, so all Dart
   state goes; observed here only as the lost run.) The SIM's mcc/mnc also changed at boot, and
   those are not in Flutter's default `configChanges`. A rescan or playback in progress can be cut
   off the same way. The storage grant was unaffected; re-running passed. Needs a decision before
   A2–A4 (see questions).
6. **`ClipPlayer.play(String path)` receives a URI.** With (a), clips are `content://` URIs, not
   filesystem paths. The interface type fits; only the parameter name is misleading (A3).
7. **Android 10 vs 14 differences** seen so far: no confirmation dialog on 10; `file_picker` path
   access is fully denied on 10 and read-denied on 14. SAF behaved the same on both.
8. **People can pick a pack folder instead of the folder that holds packs.** In a hand test on the
   POCO, the picker returned `ohrwurm-packs/a1_k02` and `ohrwurm-packs/b2_k99`, not
   `ohrwurm-packs`. The picker confirms whichever folder it is showing, and without a starting
   folder it reopens wherever it was last left — here, inside a pack. The spike assumed it had the
   root and failed with "No such file or directory". SAF returned exactly what was picked, so this
   is not a problem with approach (a). The app must recognise a picked folder that itself contains
   `manifest.json` and ask for the folder that contains the packs (APP_SPEC 5.1).

## Decisions (2026-09-23)

Recorded in `docs/APP_SPEC.md`:

- **Approach (a)**, with `saf_util` + `saf_stream` (5.1, 3).
- **Restart-safe rescans and sessions** rather than keeping the engine alive (5.2, 11.5).
- **`ClipPlayer.play(String uri)`** (11.1).
- **Preload the next clip** to hide load time; the mechanism is designed in A3's plan (11.1).
- Findings 1–4 and 8 → 5.1–5.3; finding 5 → 5.2 and 11.5; finding 6 → 11.1.

Still open: **what happens when a clip fails to load mid-session** (APP_SPEC 17). Needed by A4.
