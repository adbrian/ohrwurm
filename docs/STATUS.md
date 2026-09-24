# Status

**A3–A8 built on branch `claude/gallant-hypatia-1s4nlw` in an autonomous cloud run
(2026-09-24): not reviewed by Ian, not run on a device** (Autonomous run, below). Return point:
`a2` at `f08b44d`.

A0, A1 and **A2 complete (2026-09-24, branch `a2`)**. A2 was tested on desktop and on both
devices, reviewed by Ian, changed as he decided, and re-checked on both devices (A2 re-check,
below): 11 of 12 pass on both. Re-check 1 fails on the POCO only (the navigation bar turns white
for about half a second at the first frame); **Ian accepted it as is** (Decisions; kept under
Pending as a known issue with the likely fix).

## Autonomous run A3–A8 (branch `claude/gallant-hypatia-1s4nlw`)

**Return point: branch `a2` at `f08b44d`** — A2 done, nothing after it. Everything past that
commit is on `claude/gallant-hypatia-1s4nlw`, built by a cloud session on 2026-09-24 at Ian's
request: *go through all the phases, don't wait for confirmation, make changes as you see fit,
on a new branch*. So, unlike every step before it, **no step on this branch was planned with Ian
or approved before it was built**, and nothing was run on a device (a cloud session has no
device, emulator or adb). Claude's own decisions are in Decisions, marked *Claude's decision
(autonomous run)*, for Ian to confirm or undo. To go back: check out `a2`; to keep some of it,
cherry-pick the step commits (one or more per step, titled `A3: …` to `A8: …`).

`flutter analyze` clean, `flutter test` **285 passing** (Flutter 3.47.2; 128 at A2). The Android
build was **not** compiled: the cloud session has no Android SDK, so the new plugins' native side
(`just_audio`, `audio_session`, `wakelock_plus`, `record`, `permission_handler`,
`path_provider`) is untested until the first local build.

| Step | Commit | Built | Done-when, as far as a cloud session can show it |
|---|---|---|---|
| A3 | `781da57` | `lib/playback/listen_engine.dart` (pure Dart), `ClipPlayer` + `preload`, `test/playback/fake_clip_player.dart`; the 11.6 tests written first | All ten 11.6 scenarios pass, plus 14 more (highlight, pauses, preload, background, clip failure, end card). Deleting any generation check after an `await` fails a test, except the loop-top check, which only runs right after another check |
| A4 | `30b8f0d` | Card content and grammar line (`lib/cards/`), recipes as data, session cards with clip URIs from one listing per pack, `ListenController`, Listen screen (DESIGN 5–6), `JustAudioClipPlayer` (two players, preloading), `AudioHost` (audio session, calls, keep-screen-on), settings model | Widget tests with the fake player on the fixture packs: highlighting, swipe, Next, replay, *Replaying…*, Loop, end card, background, calls, wakelock, clip failure. **Not played on a device** |
| A5 | `e0d30a4` | Setup screen (DESIGN 4) replacing the read-only library, resume prompt (DESIGN 3), end card actions, card limit, unheard first, deck builder; **Settings screen** (DESIGN 9) | Deck, resume (dropped cards, most gone), setup and resume widget tests. Force-close resume is covered by the saved position, **not tried on a device** |
| A6 | `bb9b255` | (Behaviour came with A4–A5.) Tests for the done-when | *der_freund* heard in `a1_k02` counts in `a1_nb01`; `gehen` and `gehen_2` separate; also-in; progress survives rescans |
| A7 | `022650f` | (Behaviour came with A4–A5.) All 48 words / focus / style / Q&A-translation combinations tested | Checked against an independent reading of the manifests, with a synthetic pack for plural and feminine Q&A (the fixtures have none) |
| A8 | `0686a5b` | Mirror controller and screen (DESIGN 7), recorder, microphone permission, `RECORD_AUDIO` | Record, stop, play mine, replace, discard on swipe and on leaving, refusal and refusal for good, Q&A boxes, setup routing. **No real microphone** |

**Also changed:** the `Focus` enum is now `WordFocus` (it clashed with Flutter's `Focus`
widget; stored values unchanged). `dart format` (line length 100) was run over `lib` and `test`,
which re-wrapped some A2 files: whitespace only. `lib/library/library_screen.dart` is gone; setup
is the library now. The A4 stop-gap (tap a pack to listen) was replaced by setup in A5.

**Unsure about, for Ian or the device check:**
- `JustAudioClipPlayer`: that `play()`'s future completes at the clip's end and on `pause()`, as in
  A0; that `seek(0)` replays a completed source; that preloading into the second player hides the
  load. Only a device shows it.
- The swipe feel (threshold 90 px, tilt `dx / 42`°, 180 ms fly-off) and the 1.1 s pulse.
- Interruptions: calls stop the card and restart it when they end; short sounds are left to
  Android's automatic ducking (`androidWillPauseWhenDucked: false`).
- Mirror's recording format (AAC `.m4a`, mono) and the play-and-record session on the POCO.
- Wording written in DESIGN's voice without Ian's review: `lib/session/copy.dart` (status line on
  a failed clip, resume and end-card lines, *0 cards* explanations, Mirror microphone messages)
  and `lib/settings/settings_screen.dart` (pause labels and rationale; the German-sentence one is
  DESIGN's).

## Next step

**Ian reviews the autonomous run** (above) and its decisions (Decisions, *Claude's decision
(autonomous run)*): keep, change or drop. If it's kept, a **local session** runs the device check
below; if not, work continues from `a2` at `f08b44d`.

**Device check A3–A8 (local session, POCO and emulator).** Build a debug APK from the head of
`claude/gallant-hypatia-1s4nlw` and install it over the A2 build (data kept; the folder stays
`Download/ohrwurm-packs`). The first build is the first time the new plugins compile: if it fails,
record the error and stop. Record results in a new "A3–A8 device check" section; don't fix
failures in the local session. Clips are tones (fixtures) or speech (`a1_k01`, POCO).

| # | Do | Should appear |
|---|---|---|
| 1 | Launch | Setup (*Your packs*) with the pack cards, each with *0 / N heard* and a thin bar; options below; footer *0 packs · 0 cards*, **Start** disabled |
| 2 | Select *Freunde, Kollegen und ich* (emulator) or *Guten Tag!* (POCO), then *A1 · Notebook 1* | Accent border and check on each; footer counts packs and cards; **Start** enabled |
| 3 | Start (Listen, defaults) | The Listen card: headword, translation, grammar line, *also in …* where it applies, one segment per line. **Sound plays**, and the highlight follows it line by line; *Your turn — understand it before the English* in the pause after the German sentence; no gap or stutter between lines (preload) |
| 4 | Let a card finish (looped) | *Looping — swipe when you're ready*, then the same card again |
| 5 | Swipe mid-line, in a pause, and in the gap; then five fast swipes | Audio stops at once; exactly one card per swipe; five swipes move five cards, nothing left playing |
| 6 | Tap the card; **Again**; **Next** | Tap and Again restart at the headword with *Replaying…*; Next moves on |
| 7 | Loop pill off; let a card finish | *Moving on…*, then the next card |
| 8 | Home button, wait, return | Sound stops at once; on return the card restarts from its headword |
| 9 | Screen timeout short (e.g. 30 s), leave a card looping | The screen stays on while the session is open |
| 10 | Force-stop mid-session, relaunch | *PICK UP WHERE YOU LEFT OFF* with the packs, options and *N of M*; **Resume** lands on the same card |
| 11 | Swipe past the last card (use a card limit of 10 to get there) | The end card: **Restart**, **Reshuffle**, **Change selection** all work |
| 12 | Back to setup | The packs heard show *N / M heard*; a word heard in one pack counts in the other (`der_freund`) |
| 13 | Settings (gear): change speed to 0.75× and the German-sentence pause to 3 s; start a session | Clips slower, pauses unchanged except the German-sentence one |
| 14 | Mirror, statements: **Play**, **Record** (first time: the permission dialog; allow), speak, **Stop**, **Play mine** | The German clip plays; *Stop · 0:0N* counts while recording and the box border is accent; your recording plays back |
| 15 | Mirror: deny the microphone once (clear the app's permission first) | Record explains why it can't work; after *Don't ask again*, it says how to allow it, and *Open settings* opens the app's settings |
| 16 | Mirror: swipe after recording | Next card; *Play mine* gone |
| 17 | During a Listen session, have someone call (or play a notification sound) | A call stops the card, which restarts when the call ends; a notification only ducks |

The A2 re-check instructions below were run on 2026-09-24 (local session) and are kept for
reference.

Build a debug APK from the head of `a2` and install it **over** the current A2 build on the POCO and
the emulator (keep the data: the saved folder and the database stay). The folder stays
`Download/ohrwurm-packs` throughout. Record the results in a new "A2 re-check" section here; don't
fix failures in the local session. Fixture files to put back are in `test/fixtures/packs/`.

| # | Re-check (decision) | Do | Should appear |
|---|---|---|---|
| 1 | Launch window (finding 1) | Force-stop the app, then tap its launcher icon. Do it twice on each device | Dark (`#0E0E13`) from the first frame to the app. **No white frame at all**, then the library. Screenshot or `adb shell screenrecord` the start |
| 2 | First launch after the install (finding 2) | Let the launch rescan finish | The result screen once: the install starts with no remembered rejections, so `a1_k03` counts as new |
| 3 | Result rows (finding 3) | Look at that result screen | Titled packs have the label first in the detail line: *Guten Tag!* / *A1 · Chapter 1 · unchanged* (POCO only), *Freunde, Kollegen und ich* / *A1 · Chapter 2 · unchanged*, *In der Stadt* / *A1 · Chapter 3 · not loaded · 1 audio file missing*, *Stress test* / *B2 · Chapter 99 · unchanged*. Untitled: *A1 · Notebook 1* / *unchanged*. *notes* / *no manifest · skipped* |
| 4 | Icons (open point 1) | On the result screen and the library, look at the back arrow, the folder tile and the rescan button | Thin stroked Phosphor icons (arrow left, folder, circular arrow), not Material ones, and **not empty boxes** (a missing font shows as boxes or nothing). The headphone tile on first launch is checked in 11 |
| 5 | System back (open point 4) | On the result screen, use the system back (gesture or button) | The library (*Your packs*). The app doesn't close |
| 6 | Rejection not repeated (finding 2) | Force-stop, relaunch. Wait for *Checking the folder…* to end | The library stays. The result screen **does not** come back, although `a1_k03` is still broken |
| 7 | Rescan still shows it (finding 2) | Tap the rescan button in the library | The result screen, with the `a1_k03` row and *One pack wasn't loaded. Nothing else changed.* Back to the library |
| 8 | New reason is news (finding 2) | `adb shell rm` a second clip from `/sdcard/Download/ohrwurm-packs/a1_k03/` (any `.ogg`), then force-stop and relaunch | The result screen returns: *In der Stadt* / *A1 · Chapter 3 · not loaded · 2 audio files missing*. Put that clip back afterwards (`adb push` from `test/fixtures/packs/a1_k03/`) and relaunch: the result shows once more (*1 audio file missing* again) |
| 9 | *Not loaded* tag (open point 2) | `adb shell rm /sdcard/Download/ohrwurm-packs/a1_nb01/a1_nb01__der_freund__translation.ogg`, force-stop, relaunch | Result screen: *A1 · Notebook 1* / *not loaded · 1 audio file missing · progress kept*, ringed disc; verdict *2 packs weren't loaded. Nothing else changed.* Back: the *A1 · Notebook 1* card is dimmed and tagged **Not loaded** (not *Not found*) |
| 10 | Tag remembered (open point 2) | Force-stop, relaunch; look at the card while *Checking the folder…* shows | *Not loaded* from the first frame, not *Not found* changing to *Not loaded*. The library stays. Then `adb push` the clip back from `test/fixtures/packs/a1_nb01/` and relaunch: the card is available again, no tag |
| 11 | Headphone icon (open point 1) | Emulator only, last: clear the app's storage (Settings → Apps → Ohrwurm → Storage → Clear), launch; then *Choose folder* → `Download/ohrwurm-packs` | First launch: the headphone icon in its accent-outlined tile, drawn as a Phosphor stroke (not a box). Choosing the folder gives the result screen with everything *added*, then the library as before |
| 12 | Phase timings (finding 4) | `adb logcat \| grep ohrwurm.rescan` during a relaunch on each device, and one **Rescan** | Per-folder lines like `ohrwurm.rescan a1_k01 817 ms (list …, read …, check …): unchanged` (`save …` too for added or updated packs). Record the list / read / check split for `a1_k01` (POCO) and `b2_k99` (both) in a table |

Everything else in A2 is unchanged and needs no re-check. The emulator has no `a1_k01`, so it skips
that row in 3.

## A2 re-check (2026-09-24)

Local session. Debug APK from `ab1ce08`, installed **over** the previous A2 build with data kept on
the POCO F1 (Android 10) and the `ohrwurm_api34` emulator (Android 14); the folder stayed
`Download/ohrwurm-packs`. Ian tapped; Claude used adb for screenshots, screen recordings (analysed
frame by frame at 30 fps), logcat, and removing and restoring clips (restored byte-identical from
`test/fixtures/packs/`). No code was changed; analyze and test were not run. The emulator shut
down during a pause and was restarted before its re-checks; its app data was unaffected.

| # | Re-check | POCO F1 (Android 10) | Emulator (Android 14) |
|---|---|---|---|
| 1 | Launch window | **Fail (partly).** Dark (`#0E0E13`) from the tap in both launches, no white window. But the **system navigation bar turns white** for ≈0.3 s (first launch) and ≈0.45 s (second) as Flutter draws its first frame, then dark again. `poco/01b-white-nav-bar-at-first-frame.png`. **Accepted as is by Ian (Decisions; Pending has the likely fix)** | Pass. Dark from the first frame; Android 14's splash shows the app icon on dark; the navigation bar stays dark |
| 2 | First launch after the install | Pass: the result screen once | Pass |
| 3 | Result rows | Pass: all six rows exactly as specified, incl. *Guten Tag!* / *A1 · Chapter 1 · unchanged* | Pass (no `a1_k01`) |
| 4 | Icons | Pass: back arrow, folder and rescan are thin Phosphor strokes, no boxes | Pass |
| 5 | System back on the result screen | Pass: the library; the app stays open | Pass. Ian's first attempts from the emulator window didn't go back (cause unknown; the log was cleared before it could be read); a back key via adb worked, and Ian's retest in 7 worked through Android 14's predictive-back callback |
| 6 | Rejection not repeated | Pass: the library stays after the relaunch rescan | Pass |
| 7 | Rescan still shows it | Pass: result screen with the `a1_k03` row | Pass |
| 8 | New reason is news | Pass: *2 audio files missing*; after restoring, shown once more with *1 audio file missing* | Pass |
| 9 | *Not loaded* tag | Pass: *not loaded · 1 audio file missing · progress kept*, ringed disc, *2 packs weren't loaded. Nothing else changed.*; library card dimmed, **Not loaded** | Pass |
| 10 | Tag remembered | Pass: *Not loaded* in the first library frame (recorded), through *Checking the folder…*; library stays. Clip restored: available, no tag (logged *unchanged*, no result screen) | Pass |
| 11 | Headphone icon (emulator only) | — | Pass: Phosphor stroke in the accent-outlined tile. After *Choose folder* (Android 14 asked for access again): everything *added*, *One pack wasn't loaded. The rest are ready.* |
| 12 | Phase timings | Recorded below | Recorded below |

**Row 12 — rescan phases** (debug build, ms; logged as
`ohrwurm.rescan <folder> <total> (list, read, check[, save])`):

| Device | Run | Pack | Total | List | Read | Check | Save |
|---|---|---|---|---|---|---|---|
| POCO | First launch after install | `a1_k01` | 930 | 396 | 20 | 512 | — |
| POCO | First launch after install | `b2_k99` | 389 | 203 | 15 | 170 | — |
| POCO | Relaunch | `a1_k01` | 764 | 332 | 16 | 414 | — |
| POCO | Relaunch | `b2_k99` | 314 | 162 | 8 | 142 | — |
| POCO | Rescan (button) | `a1_k01` | 549 | 305 | 18 | 224 | — |
| POCO | Rescan (button) | `b2_k99` | 256 | 141 | 7 | 108 | — |
| Emulator | First launch after install | `b2_k99` | 915 | 741 | 11 | 163 | — |
| Emulator | Relaunch | `b2_k99` | 918 | 714 | 9 | 195 | — |
| Emulator | Rescan (button) | `b2_k99` | 966 | 879 | 9 | 76 | — |
| Emulator | After clearing storage (added) | `b2_k99` | 948 | 712 | 11 | 167 | 55 |

Rescan totals: POCO 2,651 (first launch) / 2,189 (relaunch) / 1,035 ms (Rescan button); emulator
3,040 / 2,517 / 1,281 ms; after clearing storage 3,575 ms. Listing the folder is the largest share
of `b2_k99` on both devices (≈75–90% on the emulator, ≈50–55% on the POCO). For `a1_k01` on the
POCO, list and check are close: check was larger at launch, list on the Rescan button. The first
*added* pack after a storage clear (`a1_k02`) spent 1,624 ms in `save` — the first write to a fresh
database.

**Also noted, not part of a re-check:**
- On the emulator the splash shows **Flutter's default app icon**: the app has no icon of its own
  yet.
- On the POCO, after the dark launch window, the debug build shows an empty dark screen for
  ≈3.4 s before the library (≈5 s on the emulator). Debug builds start slowly; not measured in
  release.

Screenshots: `docs/screenshots/a2-recheck/poco/` and `docs/screenshots/a2-recheck/emulator/`.

## A2 device results (2026-09-24)

Local session. Debug APK from `0a24dc6`, installed on the POCO F1 (Android 10) over the A1 build (no
saved folder, empty database), and freshly on the `ohrwurm_api34` emulator (Android 14). Ian
tapped; Claude used adb for screenshots, logcat and renaming the pack folder. The emulator has no
`a1_k01`. No code was changed and analyze/test were not run in this session.

| Check | POCO F1 (Android 10) | Emulator (Android 14) |
|---|---|---|
| First launch (DESIGN 1) | Pass | Pass |
| *Choose folder* → `Download/ohrwurm-packs` → result screen | Pass: `a1_k01`, `a1_k02`, `a1_nb01`, `b2_k99` *added*; `a1_k03` *not loaded · 1 audio file missing*; `notes` *no manifest · skipped*; *One pack wasn't loaded. The rest are ready.* | Pass, same without `a1_k01` (no "Allow access?" dialog on Android 10; Android 14 asks) |
| Library (back arrow) | Pass: *Your packs*, 4 cards in sort order, meta lines per DESIGN 4. `a1_k03` absent — correct, it was never a known pack | Pass, 3 cards |
| Relaunch: library at once, rescan behind it | Pass: library with *Checking the folder…* shows before the rescan ends (≈1.3 s here), then the result screen returns because `a1_k03` is still broken | Pass, same |
| Stale access: folder renamed, relaunch | Pass: *Can't reach your pack folder*, no empty library. Database untouched: all 4 packs still `available = 1`, 335 cards | Pass |
| *Try again* while still missing | Pass: stays on the stale screen | Pass |
| *Try again* after the folder is back | Pass: recovers without re-picking, all *unchanged* | Pass |
| Pick a pack folder (`a1_k02`) as root | Pass: *That looks like one pack*; the saved folder is not replaced. Choosing the parent then loaded everything *unchanged* | Pass (screenshot `emulator/06-looks-like-one-pack.png`); saved folder confirmed unchanged |
| Folder saved as the tree URI | Pass: `tree/primary%3ADownload%2Fohrwurm-packs` in DataStore | Pass |

**Rescan timings** (`adb logcat | grep ohrwurm.rescan`, debug build, ms):

| Folder | POCO first scan | POCO relaunch | Emulator first scan | Emulator relaunch |
|---|---|---|---|---|
| `a1_k01` (2,267 files, 200 cards) | 908 | 817 | — | — |
| `b2_k99` (1,501 files, 125 cards) | 366 | 333 | 1,061 | 1,937 |
| `a1_nb01` | 455 | 374 | 72 | 104 |
| `a1_k02` | 63 | 34 | 256 | 619 |
| `a1_k03` (rejected) | 56 | 48 | 41 | 96 |
| `notes` (skipped) | 8 | 7 | 16 | 24 |
| **Total** | **2,081** | **2,247** | **4,007** | **3,807** |

Other full rescans: POCO 2,330 / 2,095 / 2,345 / 2,207 ms; emulator 2,028 ms. Stale checks
(`RootUnavailable`): POCO 181–766 ms, emulator 41–819 ms. Pack folder as root (`RootIsAPack`):
POCO 93 ms, emulator 348 ms. The first folder scanned carries some one-off cost (`a1_nb01` on the
POCO, `a1_k02` on the emulator).

**Failed or looked wrong** — nothing failed; for Ian's review:
1. **White launch window on every cold start.** The screen is white until Flutter's first frame,
   then fades into the dark app: ≈1.5 s on the POCO, several seconds on the emulator (debug builds
   start slowly, so release will be shorter, but the white is the template's launch background and
   shows in any build). Ian noticed it. Screenshots `*/04a-relaunch-white-launch-window.png`.
2. **The result screen returns on every launch while a pack is broken** (the known open point,
   confirmed on device). The library is visible for only about a second first; Ian didn't notice it.
3. **Result-screen rows show only the title** for titled packs (*Guten Tag!*, *Stress test*), with
   no *A1 · Chapter 1*; untitled packs show *A1 · Notebook 1*. The library cards do show both.
4. **Every launch re-validates every pack**, so a relaunch costs about as much as the first scan
   (≈2.2 s on the POCO for these five packs, ≈0.9 s for `a1_k01` alone). It runs in the background
   and doesn't block the library, but it grows with the number of chapters.
5. **Emulator first scan: ≈2.5 s before the first folder finished** (per-folder times sum to
   ≈1.4 s of 4.0 s), against ≈0.2 s on the POCO and ≈1 s on the emulator relaunch. Not
   investigated; for the cloud session to look at if it matters.

Ian's decisions on these (2026-09-24, Decisions below): 1 dark launch window; 2 a rejection
shows the result screen only when it's new; 3 the label leads titled packs' detail lines; 4 keep
re-validating, split the timing log by phase to decide later; 5 accepted as emulator/debug
cold-start cost.

Screenshots for the design review: `docs/screenshots/a2/poco/` and `docs/screenshots/a2/emulator/`
(first launch, result, library, relaunch frames, stale access, recovery, one pack, re-pick).

## A2 progress

`flutter analyze` clean; `flutter test` 128 passing (Flutter 3.47.2, as in `.metadata`). Was 117
before Ian's review changes.

**Built:**
- `lib/packs/`: `PackStorage` + `SafPackStorage` (SAF, tree URI stored); `manifest.dart`
  (`ManifestValidator` on `json_schema` 5.2.2 without format assertion, `PackManifest.read`,
  `Rejection`s, pure `checkManifest`); `rescanner.dart` (APP_SPEC 5.2: checks the root, spots a
  pack folder picked as root, lists each subfolder once, validates in `Isolate.run`, reconciles one
  transaction per pack, marks missing or rejected known packs unavailable, never touches
  progress); `pack_display.dart` (headings, meta lines, 4.3 labels).
- `lib/library/`: `LibraryController` (`ChangeNotifier`; folder URI in `shared_preferences` via
  `SharedPreferencesAsync`; shows the library from the database at once and rescans behind it;
  one rescan at a time; the folder is saved only after it scans as a folder of packs); screens:
  first launch (DESIGN 1), rescan result (DESIGN 2), read-only library (DESIGN 4 cards), stale
  access, "looks like one pack", and a plain-text first-scan screen; all wording in `copy.dart`.
- `schema/manifest.v2.schema.json` declared as an asset and loaded as it is.
- Tests: validator (4 valid manifests incl. `a1_k01`, 25 single-point breakages in
  `test/packs/manifest_breakages.dart`, all 29 cross-checked against Python `jsonschema`),
  reader, `checkManifest`, rescan on a temp copy of the fixtures via `DirectoryPackStorage`
  (the A2 "done when" cases: valid packs load, `a1_k03` rejected whole, `notes` ignored, an update
  keeps progress, an unavailable pack stays listed), controller, and widget tests.
- `test/fixtures/real/README.md` marks `a1_k01_manifest.json` as a pipeline snapshot.

**Changes from Ian's review (2026-09-24, cloud session; not yet re-checked on a device):**
- Android launch window and window background are DESIGN's `bg`
  (`android/app/src/main/res/values/colors.xml`, both `styles.xml`, both `launch_background.xml`).
  Not buildable in the cloud session (no Android SDK): re-check 1.
- `RejectionStore` (`PrefsRejectionStore`, key `last_rejections` in `shared_preferences`) keeps the
  last rescan's rejections as `rejectionKey`s: the folder plus the reason as reported (type, and
  the number of missing clips). An automatic rescan shows the result when a pack was added,
  updated or newly went missing (`RescanReport.loadedOrLost`), or a rejection isn't in the store.
  The library tags an unavailable pack *Not loaded* when its folder is in the store
  (`LibraryController.wasRejected`), loaded before the library first shows.
- `rowDetail` puts `packLabel` first for titled packs.
- The rescan timing log gives each folder's phases: `(list, read, check[, save])`.
- `PopScope` on the result screen: the system back goes to the library.
- Phosphor regular font bundled as `assets/fonts/Phosphor-Regular.ttf` (MIT,
  `Phosphor-LICENSE.txt`), taken from the official `phosphor_flutter` 2.1.0, which itself doesn't
  compile on Flutter 3.47 (`IconData` is final). `AppIcons` are `IconData` in family `Phosphor`,
  with that package's codepoints (checked against the font's cmap). No Dart package added.
- DESIGN 2 and 4 now describe: the back arrow, *not found* rows, the disc drawing, the label in the
  detail line, *The rest are ready.*, the empty-folder panel and line, and the *Not loaded* tag.
- Tests: controller (rejection shown once; Rescan still shows it; new reason; fixed then broken;
  *Not loaded* remembered before the launch rescan ends; missing ≠ rejected), rescanner (rejection
  keys, `loadedOrLost`, phase log), widgets (label in rows, *Not loaded* tag, system back), icons.

## Done

- **A0** — storage and playback spike on branch `spike/a0` (`3a8857e`); passes on the POCO F1
  (Android 10) and an API 34 emulator, including relaunch, reboot and update. Results:
  `docs/A0_FINDINGS.md`. Ear test on the POCO passed (2026-09-24): Ian heard the six tones.
- **A1** — Flutter project at the repository root, theme tokens (DESIGN.md), bundled Inter,
  database schema v1 with `onUpgrade` migrations, data-access layer (packs, cards, progress,
  session). `flutter analyze` clean, `flutter test` 36 passing. **On the POCO (2026-09-24):** first
  launch creates `databases/ohrwurm.db` with the four tables and both indexes, `user_version` 1,
  integrity ok, no foreign keys; a second launch reopens it without rewriting it.
- **A2** — schema validation, rescan and reconcile, read-only library, on branch `a2` (not yet
  merged to `main`). `flutter analyze` clean, `flutter test` 128 passing. Device checks and the
  re-check after Ian's review pass on the POCO F1 and the API 34 emulator, except the POCO's white
  navigation bar at the first frame, accepted as is (A2 re-check; Pending). Reported done
  2026-09-24.

## Built, not yet reviewed or device-checked

- **A3–A8** — branch `claude/gallant-hypatia-1s4nlw`, autonomous cloud run (above). Tests pass;
  no device run; no Android build.

## Decisions

Every decision Ian makes is recorded here: date, what, why. Where the reason wasn't given, it says
so. APP_SPEC and DESIGN remain the source of truth for behaviour; this is the log of choices.

| Date | Decision | Why |
|---|---|---|
| 2026-09-23 | Minimum Android 10 (API 29) (APP_SPEC 3) | The POCO F1 on Android 10 is Ian's own phone and the device the app will be used on |
| 2026-09-23 | A0 must pass on the POCO **and** an Android 14 (API 34) emulator | Cover the real device and current Android |
| 2026-09-23 | Application id `io.github.adbrian.ohrwurm` | Chosen by Ian (CLAUDE.md rule 8); reason not stated |
| 2026-09-23 | Spike uses `io.github.adbrian.ohrwurm.spike`, on branch `spike/a0` in `spike/a0_storage/` | Keep the spike's permissions and data apart from the real app |
| 2026-09-23 | A0 findings go in `docs/A0_FINDINGS.md` on `main` | So later steps can refer to them |
| 2026-09-23 | Prefer maintained packages; a Kotlin platform channel is pre-approved if they don't work | Not needed in the end |
| 2026-09-23 | A 1,500-clip stress pack, generator kept in `spike/` (not `tool/`) | Fixture packs are too small to time rescans |
| 2026-09-23 | **Approach (a) read in place**, `saf_util` + `saf_stream`; not `file_picker` (APP_SPEC 3, 5.1) | A0: works on both devices; no duplicated storage; (b) adds 7–11 s per chapter and still needs SAF; `file_picker` can't read the packs |
| 2026-09-23 | Store the tree URI; recognise a picked pack folder (APP_SPEC 5.1) | A0 findings 4 and 8 |
| 2026-09-23 | Rescan lists each pack once; one transaction per pack (APP_SPEC 5.2) | A0 finding 1: per-file lookups take minutes per chapter; finding 5 |
| 2026-09-23 | Stale access checks the root itself; *Try again* before re-selecting (APP_SPEC 5.3) | A0 findings 2 and 3: a moved folder lists as empty; storage can look missing just after boot |
| 2026-09-23 | Restart-safe rescans and sessions, not a kept-alive engine (APP_SPEC 5.2, 11.5) | A0 finding 5: Android can recreate the activity at any time |
| 2026-09-23 | `ClipPlayer.play(String uri)` (APP_SPEC 11.1) | A0 finding 6: clips are `content://` URIs, not paths |
| 2026-09-23 | Preload the next clip; mechanism designed in A3's plan (APP_SPEC 11.1) | A0: 60–170 ms load per clip, 450–550 ms for the first after install or reboot |
| 2026-09-23 | `main` ignores `spike/` | The spike lives only on `spike/a0` |
| Before 2026-09-24 (earlier session; confirmed 2026-09-24) | A1 plan approved, including **`provider`** for state management | Reason not recorded in the repo |
| Before 2026-09-24 (earlier session; confirmed 2026-09-24) | "Also in" returns **distinct, available** packs only, excluding the current pack (APP_SPEC 8) | Reason not stated; matches section 8's own wording, "other **available** packs" |
| 2026-09-24 | Commit A1 on `main` | A1 passed on the POCO |
| 2026-09-24 | Record every decision here with date, what and why | So a new session doesn't have to ask |
| 2026-09-24 | Test A2 with the real pipeline pack `a1_k01` (Kapitel 1, *Guten Tag!*) as well as the fixtures | It's now on the POCO in `Download/ohrwurm-packs/` |
| 2026-09-24 | A2 plan approved; don't start building until Ian resumes | Ian taking a break |
| 2026-09-24 | Schema validator: **`json_schema` 5.2.2**, `format` not asserted (APP_SPEC 4.1) | Agreed with Python `jsonschema` on all 29 test cases; works offline. `json_schema_builder` fetches the meta-schema over the network. Unchecked `format` is the 2020-12 default and matches `tool/make_fixture_pack.py`; `json_schema`'s date-time check accepts a missing timezone |
| 2026-09-24 | A2 "pack list screen" = **read-only library**: pack cards per DESIGN 4 (heading, meta line, word count; unavailable dimmed with *Not found*), sorted, with a **Rescan** action. No selection, progress or options yet | Claude's proposal, accepted: selection, progress and options belong to A5–A6 |
| 2026-09-24 | A known pack that **fails validation** on rescan becomes **unavailable**; its rows and progress are kept; the reason shows on the result screen | Claude's proposal, accepted: with read-in-place its clips may really be gone; the spec only covered "no longer found" |
| 2026-09-24 | Result screen (DESIGN 2) only when something changed (added, updated, rejected, went missing); **always** after a manual Rescan | Claude's proposal, accepted; Ian's reason not stated |
| 2026-09-24 | **Rescan never blocks the library**: show the library from the database immediately, rescan in the background, update when done | Ian's addition; reason not stated |
| 2026-09-24 | Wording not in DESIGN (stale access, *Try again*, "looks like one pack", rejection reasons): Claude proposes it in DESIGN's voice, **describing failures by what was protected**; Ian reviews | Reason not stated; DESIGN's Copy section already asks for failures described by what was protected |
| 2026-09-24 | Push A2 work in progress and continue it in a cloud session | Ian's choice; reason not stated |
| 2026-09-24 | Continue A2 in a cloud session on branch `a2` | Ian's instruction |
| 2026-09-24 | **Local sessions only for what needs Ian's machine** (devices, emulator, adb). Everything else — code changes, fixes, analyze and tests, docs — in a cloud session. A local session records device results in STATUS, commits and pushes; it doesn't fix failures | Ian's instruction |
| 2026-09-24 | **Launch window is DESIGN's `bg`**, no image, in light and dark system modes (A2 finding 1) | Ian gave no reason. Claude's case: the template's white window shows on every cold start and fades into the dark app; DESIGN has no splash screen, so no image |
| 2026-09-24 | **A rejection opens the result screen after an automatic rescan only when it's new**: a folder plus reason not in the last rescan's rejections, kept in `shared_preferences`. A new reason, or a pack fixed and broken again, is new. Manual Rescan always shows everything. Added, updated and newly missing packs still show it (A2 finding 2; refines the 2026-09-24 "only when something changed" decision) | Ian gave no reason. Claude's case: a broken pack otherwise brings the result screen back at every launch; this treats a rejection like a missing pack, reported when it happens |
| 2026-09-24 | **Result rows for titled packs start the detail line with the label**: *A1 · Chapter 1 · added · 200 words* (A2 finding 3; APP_SPEC 4.3, DESIGN 2) | Ian gave no reason. Claude's case: APP_SPEC 4.3 puts the label beneath a title everywhere; same pattern as the library's meta line |
| 2026-09-24 | **Keep validating every pack at every rescan for now; split the debug timing log by phase** (list, read, check, save) and decide with device numbers (A2 finding 4) | Ian gave no reason. Claude's case: only schema checking could be skipped, and it's unknown whether it or SAF listing dominates |
| 2026-09-24 | **Emulator first-scan delay accepted** as emulator/debug cold-start cost; no investigation or logging (A2 finding 5) | Ian gave no reason |
| 2026-09-24 | **Phosphor icons, regular weight.** First approved as the `phosphor_flutter` package; it doesn't compile on Flutter 3.47, so instead **Phosphor's regular font is bundled** (MIT, from the official package), with `IconData` constants in `AppIcons`. No Dart package added (DESIGN Icons) | Ian gave no reason. Claude's case: DESIGN asks for Phosphor; bundling the font like Inter adds no third-party code to break on Flutter upgrades. Community forks were the other option |
| 2026-09-24 | **A known pack rejected on rescan is tagged *Not loaded*** in the library; *Not found* only when its folder is gone. Known from the stored rejections, so right from launch (DESIGN 4) | Ian gave no reason. Claude's case: *Not found* was untrue for a folder that's there; a remembered tag avoids a label that flips a second after launch |
| 2026-09-24 | Verdict *One pack wasn't loaded. The rest are ready.* when the same rescan also added or updated packs; DESIGN's *Nothing else changed.* otherwise (DESIGN 2) | Ian gave no reason. Claude's case: DESIGN's words are untrue in that case |
| 2026-09-24 | **The result screen keeps its back arrow to the library**, and the system back does the same (DESIGN 2) | Ian gave no reason. Claude's case: with a rejection, **Rescan** alone gives no way on |
| 2026-09-24 | **Empty folder**: neutral panel and library line *No packs in this folder yet. Copy your pack folders into it, then rescan.*, button **Rescan** (DESIGN 2, 4) | Ian gave no reason |
| 2026-09-24 | **Known packs no longer found get a result row**: ringed disc, *not found · progress kept* (DESIGN 2; APP_SPEC 5.2's report) | Ian gave no reason. Claude's case: APP_SPEC 5.2 reports unavailable packs |
| 2026-09-24 | Discs are 12 px: filled accent; 1.5 px `neutral400` ring (hollow); 3 px `neutral400` ring (ringed); 1.5 px `neutral600` ring (skipped) (DESIGN 2) | Ian gave no reason; approved as seen on the POCO screenshots |
| 2026-09-24 | **No *Change folder* outside the stale-access screen until Settings** (APP_SPEC 14); Settings has no build step yet — which step gets it is Ian's call | Ian gave no reason. Claude's case: the spec puts it in Settings; Ian's folder is fixed |
| 2026-09-24 | **A2 wording approved as proposed** (`lib/library/copy.dart`, listed in DESIGN 2 and 4 and in the device re-check), plus *Not loaded* | Ian gave no reason |
| 2026-09-24 | Don't commit `a1_k01`'s audio. **Commit its manifest** as `test/fixtures/real/a1_k01_manifest.json`, marked as a pipeline snapshot, with a validator test that it passes | Cross-repo check that the app's and pipeline's schema copies still agree; the audio is 21 MB |
| 2026-09-24 | **Accept the POCO's white navigation bar at the first frame as is** (A2 re-check 1): no fix now; kept under Pending as a known issue so it can be fixed later. **A2 reported done** | Ian gave no reason. Claude had recommended fixing it (every cold start on Android 10, the minimum version; a small, contained change) |
| 2026-09-24 | Build A3–A8 without stopping for approval, on a new branch; note the return point | Ian's instruction |
| 2026-09-24 | **Preload: `ClipPlayer.preload(uri)`**, a synchronous hint the engine never awaits, given the next clip as each clip starts (the next card's first clip before the gap; the same card's in looped mode). `JustAudioClipPlayer` loads it into a second player (APP_SPEC 11.1) | Claude's decision (autonomous run): adds no `await` to the engine and leaves `play`/`stop` as they are |
| 2026-09-24 | **A clip that fails to play stops the card there**: not heard, no advance; the status line says the line couldn't be played and to rescan or swipe (APP_SPEC 17's open decision) | Claude's decision (autonomous run): like a rejected pack, never half-played silently; the user stays in control |
| 2026-09-24 | **Looped mode also waits the between-cards pause before repeating** (APP_SPEC 11.2's pseudocode has no gap when looped) | Claude's decision (autonomous run): DESIGN 5 shows *Looping — swipe when you're ready* "in the gap, looped mode" |
| 2026-09-24 | **Focus doesn't apply in Mirror** (hidden in setup; Mirror always shows base examples) | Claude's decision (autonomous run): APP_SPEC 12's boxes are base examples only, so a focus would filter without changing anything shown |
| 2026-09-24 | **Reshuffle** shuffles the session's own cards again; options unchanged | Claude's decision (autonomous run): APP_SPEC 10.3 "new order, same options" |
| 2026-09-24 | **Resume drops gone cards from the saved order** when fewer than half are gone, keeping the position on the same card; cards in unavailable packs count as gone | Claude's decision (autonomous run): APP_SPEC 10.2; their clips can't play |
| 2026-09-24 | The resume prompt shows once per launch, when the library is ready: after the launch rescan's result screen if that shows first | Claude's decision (autonomous run) |
| 2026-09-24 | **Settings built** (APP_SPEC 14, DESIGN 9), reached from a gear in setup; pauses 0–5 s in 0.1 s steps | Claude's decision (autonomous run): the engine needs the pause settings; Settings had no build step |
| 2026-09-24 | Setup is the library: pack cards select, and carry progress; setup starts with the saved session's selection and options | Claude's decision (autonomous run): DESIGN 4 calls setup the main entry point |
| 2026-09-24 | Card limit: *No limit*, then 10 to 200 in steps of 10 | Claude's decision (autonomous run): APP_SPEC 10.1 says only "none / a number" |
| 2026-09-24 | *Also in* uses short names, *K2 · NB1*; a pack of another level adds it: *A2 K2* | Claude's decision (autonomous run): APP_SPEC 8's example, without ambiguity across levels |
| 2026-09-24 | Header pack names joined with *+* | Claude's decision (autonomous run): titles can contain commas and labels contain *·* |
| 2026-09-24 | Mirror's *Play mine* plays at 1×; the speed setting applies to the pack's clips | Claude's decision (autonomous run) |
| 2026-09-24 | Mirror recordings are AAC `.m4a`, mono, in the app's temporary folder | Claude's decision (autonomous run) |
| 2026-09-24 | `Focus` enum renamed `WordFocus` | Claude's decision (autonomous run): name clash with Flutter's `Focus` widget |

## Pending

- **Ian's review of the autonomous run A3–A8**, and the device check (Next step).
- **Clip fails to load mid-session** — decided provisionally by Claude in the autonomous run
  (Decisions; APP_SPEC 17); Ian to confirm.
- **Rescan cost per chapter** — decide after the phase timings in the A2 re-check (row 12) whether
  unchanged packs should skip schema checking.
- **Preload mechanism** — designed in the autonomous run (Decisions); its effect is only visible on
  a device (device check 3).
- **Known issue, accepted for now: white navigation bar at the first frame on the POCO**
  (Android 10, MIUI; A2 re-check 1, `docs/screenshots/a2-recheck/poco/01b-white-nav-bar-at-first-frame.png`).
  The launch window is dark, but the system navigation bar turns white for ≈0.3–0.45 s as Flutter
  draws its first frame, then dark again. The emulator (Android 14) is unaffected. Likely cause,
  not confirmed on a device: nothing sets the navigation bar colour — neither the launch themes
  nor the Dart code — so MIUI falls back to white when Flutter takes over. **Likely fix, if Ian
  decides to:** (1) `<item name="android:navigationBarColor">@color/ohrwurm_bg</item>` in
  `LaunchTheme` and `NormalTheme` in both `android/app/src/main/res/values/styles.xml` and
  `values-night/styles.xml`; (2) before `runApp`, `SystemChrome.setSystemUIOverlayStyle` with
  `systemNavigationBarColor` = DESIGN's `bg` and light navigation bar icons. Then a POCO-only
  re-check of re-check 1 in a local session (force-stop, launch twice, screen-record the start).
- Open since the start: displaying Mirror recording counts; colour-coding by article (on hold); iOS
  (later).

## Environment

- **POCO F1** (`cf47a954`): packs at `Download/ohrwurm-packs/` — fixtures `a1_k02`, `a1_k03`,
  `a1_nb01`, `notes`, stress pack `b2_k99`, and the real pack `a1_k01`. Installed: the app
  (`io.github.adbrian.ohrwurm`, A2 debug build from `ab1ce08`, `Download/ohrwurm-packs` chosen)
  and the spike (`…ohrwurm.spike`, data cleared). Stay-awake is off.
- **Emulator** `ohrwurm_api34` (API 34, KVM): has the fixtures and `b2_k99`, not `a1_k01`. The A2
  debug app is installed with `Download/ohrwurm-packs` chosen. Start with
  `~/android-sdk/emulator/emulator -avd ohrwurm_api34`.
- `main` ignores `spike/`; the spike lives only on `spike/a0`. Regenerate the stress pack with
  `python3 spike/make_stress_pack.py` on that branch (writes `spike/out/`, not committed).
