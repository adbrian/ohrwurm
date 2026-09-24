# Real pipeline manifests

Snapshots of manifests the pipeline produced. They are **not generated here and not hand-edited**:
replace one only with a fresh copy from the pipeline. The audio is not committed.

| File | Pack | Pipeline `generated_at` |
|---|---|---|
| `a1_k01_manifest.json` | A1 · Chapter 1, *Guten Tag!* (200 cards) | 2026-09-24T12:49:53Z |

`test/packs/manifest_test.dart` checks each one is valid against `schema/manifest.v2.schema.json`.
If that test fails after the schema copy is updated, the app's and the pipeline's schema copies
have drifted apart.

A manifest can't carry this note itself: JSON has no comments, and an extra field would fail the
schema.
