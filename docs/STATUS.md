# Status

A0 and A1 complete. **A1 passed on the POCO F1 (2026-09-24).** Next: plan A2.

## Next step

**Plan A2** (APP_SPEC 15): schema validation, rescan and reconcile, pack list screen. Test with the
fixture packs **and** the real pipeline pack `a1_k01`. Wait for approval before writing code.

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

## Pending

- **Clip fails to load mid-session** — behaviour undecided (APP_SPEC 17). Needed by A4.
- **JSON Schema validator** — chosen in A2's plan (APP_SPEC 4.1).
- **Preload mechanism** — designed in A3's plan.
- Open since the start: displaying Mirror recording counts; colour-coding by article (on hold); iOS
  (later).

## Environment

- **POCO F1** (`cf47a954`): packs at `Download/ohrwurm-packs/` — fixtures `a1_k02`, `a1_k03`,
  `a1_nb01`, `notes`, stress pack `b2_k99`, and the real pack `a1_k01`. Installed: the app
  (`io.github.adbrian.ohrwurm`, debug build) and the spike (`…ohrwurm.spike`, data cleared).
  Stay-awake is off.
- **Emulator** `ohrwurm_api34` (API 34, KVM): shut down. Has the fixtures and `b2_k99`, not
  `a1_k01`. Start with `~/android-sdk/emulator/emulator -avd ohrwurm_api34`.
- `main` ignores `spike/`; the spike lives only on `spike/a0`. Regenerate the stress pack with
  `python3 spike/make_stress_pack.py` on that branch (writes `spike/out/`, not committed).
