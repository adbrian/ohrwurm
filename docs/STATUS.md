# Status

Parked 2026-09-23, after step A0. **A1 has not been started.**

## Next step

1. **Ian: ear test on the POCO.** The automated runs showed every clip playing to completion, but
   nobody has listened. Open the spike app, already installed on the POCO (source: branch
   `spike/a0`, `spike/a0_storage/`). Tap **Pick folder (SAF)**, choose `Download/ohrwurm-packs`
   itself (tap **Use this folder** without opening a pack), then **Run checks**. After 20–40 s of
   timing checks, expect **six identical short tones** (0.6 s, 440 Hz — the `der Freund` headword
   clip): three played from the folder (a), then three from the app's copy (b). The spike's data
   was cleared, so it starts as a first launch.
2. **Then plan A1** (APP_SPEC 15) and wait for approval before writing code.

## Done

- **Spec:** minimum Android 10 (API 29); A0 on the POCO F1 and an API 34 emulator (`1e12bdb`).
- **A0 spike** on branch `spike/a0` (`3a8857e`): spike app `spike/a0_storage/` (application id
  `io.github.adbrian.ohrwurm.spike`) and stress-pack generator `spike/make_stress_pack.py`
  (`b2_k99`: 125 cards, 1,500 clips). `flutter analyze` and `flutter test` clean.
- **A0 device script passes on both devices**: pick → read manifest → play → relaunch → play without
  re-picking; also after reboot and app update. Results: `docs/A0_FINDINGS.md`.
- **A0 decisions recorded in `docs/APP_SPEC.md`** (`a795163`), and finding 8 (a picked pack folder).

## Decided

| Decision | Where |
|---|---|
| Minimum Android 10 (API 29); primary device POCO F1 | APP_SPEC 3 |
| Application id `io.github.adbrian.ohrwurm`; spike uses `io.github.adbrian.ohrwurm.spike` | this file |
| Approach (a) read in place, `saf_util` + `saf_stream`; not `file_picker` | APP_SPEC 3, 5.1 |
| Store the tree URI; recognise a picked pack folder | APP_SPEC 5.1 |
| Rescan lists each pack once; one transaction per pack | APP_SPEC 5.2 |
| Stale access: check the root itself; *Try again* before re-selecting | APP_SPEC 5.3 |
| Restart-safe rescans and sessions (not a kept-alive engine) | APP_SPEC 5.2, 11.5 |
| `ClipPlayer.play(String uri)` | APP_SPEC 11.1 |
| Preload the next clip; mechanism designed in A3's plan | APP_SPEC 11.1 |

## Pending

- **Ear test on the POCO** — not yet done by Ian (next step 1).
- **Clip fails to load mid-session** — behaviour undecided (APP_SPEC 17). Needed by A4.
- **State management choice** — proposed in A1's plan (APP_SPEC 3).
- **JSON Schema validator** — chosen in A2's plan (APP_SPEC 4.1).
- **Preload mechanism** — designed in A3's plan.
- Open since the start: displaying Mirror recording counts; colour-coding by article (on hold); iOS
  (later).

## Environment

- **POCO F1** (`cf47a954`): packs at `Download/ohrwurm-packs/` (`a1_k02`, `a1_k03`, `a1_nb01`,
  `notes`, `b2_k99`). Spike app installed with its data cleared. Stay-awake is off.
- **Emulator** `ohrwurm_api34` (API 34, KVM): shut down. It has the same packs; spike installed with
  data cleared. Start with `~/android-sdk/emulator/emulator -avd ohrwurm_api34`.
- `main` ignores `spike/`; the spike lives only on `spike/a0`. The stress pack is regenerated with
  `python3 spike/make_stress_pack.py` (writes `spike/out/`, not committed).
- A1's `flutter create` at the repository root will meet the existing `.gitignore` (one line,
  `spike/`); keep that line when Flutter's ignore rules are added.
