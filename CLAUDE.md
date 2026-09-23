# Ohrwurm — Claude Code Instructions

Ohrwurm is an offline, Android-first Flutter app for learning German vocabulary by listening. It
plays **chapter packs** — folders of short audio clips described by a `manifest.json` — produced by
a separate pipeline in another repository.

## Read first

- **`docs/APP_SPEC.md`** — behaviour, data, playback engine, build plan. Source of truth.
- **`docs/DESIGN.md`** — visual system and screens.

Read both before any task. If a request conflicts with them, or something isn't covered, **ask —
don't invent behaviour, fields or features.**

## How to work

- **One build step at a time.** The Build Plan in `APP_SPEC.md` lists steps A0–A8. Do only the step
  asked for. Plan first and wait for approval. When done, stop and report what you built, how to
  verify it, and anything you were unsure about. Don't start the next step unasked.
- **No features beyond the spec.** Check the out-of-scope list in `APP_SPEC.md` before adding
  anything.
- Before reporting a step done, run `flutter analyze` and `flutter test`. Both must be clean.

## Hard rules

1. **The manifest schema is a fixed contract.** `schema/manifest.v2.schema.json` is a copy from the
   pipeline repository. Never edit it. The app accepts any manifest that is valid against it and
   rejects any that isn't.
2. **Playback engine: check the generation counter after every `await`.** This looks redundant and
   is not. Read the engine section of the spec before touching that code. Never remove a check.
   The engine's cancellation tests are written **before** the engine and must always pass — a
   failing cancellation test is a regression, never a test to adjust.
3. **The engine is pure Dart.** It depends on a `ClipPlayer` interface, never on `just_audio`
   directly, so it can be tested with a fake player.
4. **Never display `spoken`.** It exists only for audio generation. The UI always shows `text`.
5. **Progress is never deleted.** The `progress` table has no foreign keys and no cascades. No
   rescan, pack update or cleanup may remove progress rows.
6. **Fully offline.** No network calls, analytics, crash reporting, accounts or sync.
7. **Fixture packs are generated, not hand-edited.** Regenerate them with
   `python3 tool/make_fixture_pack.py`.
8. **Don't choose the Android application id.** Ask Ian.
