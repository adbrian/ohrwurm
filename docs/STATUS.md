# Status

A0 and A1 complete. **A2 built and tested on desktop, and on both devices (2026-09-24)**: every
device check passed on the POCO and the emulator (branch `a2`). Not yet reported done: Ian reviews
the wording, the open points and the device findings first.

## Next step

1. **Ian reviews** the proposed wording and open points (A2 progress, below), the device findings
   (A2 device results, below) and the screenshots in `docs/screenshots/a2/`.
2. **A cloud session** makes whatever changes Ian decides, with `flutter analyze` and
   `flutter test`. Any change to screens or rescan needs a short device re-check in a local
   session.
3. Then A2 is reported done.

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

Screenshots for the design review: `docs/screenshots/a2/poco/` and `docs/screenshots/a2/emulator/`
(first launch, result, library, relaunch frames, stale access, recovery, one pack, re-pick).

## A2 progress

`flutter analyze` clean; `flutter test` 117 passing (Flutter 3.47.2, as in `.metadata`).

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

**Open points to raise with Ian when reporting A2** (Claude's working choices, not decided):
- Icons: DESIGN says Phosphor, which isn't in the package list; Material outlined icons stand in
  (`AppIcons` in `lib/library/widgets.dart`) unless Ian approves `phosphor_flutter`.
- A known pack rejected on rescan shows the library tag *Not found*, which is inaccurate.
- DESIGN's verdict *Nothing else changed* is untrue when the same rescan loaded packs; in that case
  the panel says *One pack wasn't loaded. The rest are ready.* instead.
- The result screen has a back arrow to the library: with a rejection, DESIGN's only button is
  *Rescan*, which gives no way on.
- An empty folder (no packs, nothing rejected): neutral panel *No packs in this folder yet. Copy
  your pack folders into it, then rescan.*, button *Rescan*; the library shows the same line.
- *Not found* rows also appear on the result screen (ringed disc, *not found · progress kept*).
  A rejected pack is reported on every rescan, so a broken pack shows the result screen at each
  launch until it's fixed.
- "Ringed" disc drawn as a thick neutral ring; hollow as a thin one.
- A2 has no *Change folder* outside the stale-access screen (Settings is later).
- Proposed wording (all in `lib/library/copy.dart`): rejection reasons *not loaded · N audio
  files missing*, *· manifest couldn't be read*, *· manifest doesn't match the pack format*,
  *· folder name doesn't match the pack (a1_k02)*, *· audio format mp3 isn't supported*,
  *· couldn't be saved on this phone*; known packs add *· progress kept*; missing pack *not found ·
  progress kept*. Stale access: *Can't reach your pack folder*, the folder tile, *The folder may
  have moved, or the phone's storage may not be ready yet. That can happen just after it starts
  up.* (or *Ohrwurm no longer has permission to read it.*) *Nothing has been deleted. Your packs
  and progress are kept on this phone.*, **Try again**, **Choose folder**. One pack: *That looks
  like one pack* / *The folder you picked has a manifest in it, so it holds a single pack. Choose
  the folder your pack folders are in, usually the one above it.* Library heading *Your packs*,
  *Checking the folder…* while a rescan runs; first scan *Reading your packs…*.

## Done

- **A0** — storage and playback spike on branch `spike/a0` (`3a8857e`); passes on the POCO F1
  (Android 10) and an API 34 emulator, including relaunch, reboot and update. Results:
  `docs/A0_FINDINGS.md`. Ear test on the POCO passed (2026-09-24): Ian heard the six tones.
- **A1** — Flutter project at the repository root, theme tokens (DESIGN.md), bundled Inter,
  database schema v1 with `onUpgrade` migrations, data-access layer (packs, cards, progress,
  session). `flutter analyze` clean, `flutter test` 36 passing. **On the POCO (2026-09-24):** first
  launch creates `databases/ohrwurm.db` with the four tables and both indexes, `user_version` 1,
  integrity ok, no foreign keys; a second launch reopens it without rewriting it.

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
| 2026-09-24 | Don't commit `a1_k01`'s audio. **Commit its manifest** as `test/fixtures/real/a1_k01_manifest.json`, marked as a pipeline snapshot, with a validator test that it passes | Cross-repo check that the app's and pipeline's schema copies still agree; the audio is 21 MB |

## Pending

- **Clip fails to load mid-session** — behaviour undecided (APP_SPEC 17). Needed by A4.
- **A2 wording** — to be proposed during A2 and reviewed by Ian.
- **Preload mechanism** — designed in A3's plan.
- Open since the start: displaying Mirror recording counts; colour-coding by article (on hold); iOS
  (later).

## Environment

- **POCO F1** (`cf47a954`): packs at `Download/ohrwurm-packs/` — fixtures `a1_k02`, `a1_k03`,
  `a1_nb01`, `notes`, stress pack `b2_k99`, and the real pack `a1_k01`. Installed: the app
  (`io.github.adbrian.ohrwurm`, A2 debug build from `0a24dc6`, `Download/ohrwurm-packs` chosen)
  and the spike (`…ohrwurm.spike`, data cleared). Stay-awake is off.
- **Emulator** `ohrwurm_api34` (API 34, KVM): has the fixtures and `b2_k99`, not `a1_k01`. The A2
  debug app is installed with `Download/ohrwurm-packs` chosen. Start with
  `~/android-sdk/emulator/emulator -avd ohrwurm_api34`.
- `main` ignores `spike/`; the spike lives only on `spike/a0`. Regenerate the stress pack with
  `python3 spike/make_stress_pack.py` on that branch (writes `spike/out/`, not committed).
