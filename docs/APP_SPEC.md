# Ohrwurm App — Specification

Single source of truth for the app. Build in the order of the **Build Plan** (section 15), one step
at a time. Visual design is in `docs/DESIGN.md`.

---

## 1. What the app does

You see a German word, its meaning, its grammar and example sentences, and hear each line spoken
while you read along. **The line currently sounding is highlighted.** Seeing and hearing together is
the point: it lets a beginner hear where one German word ends and the next begins.

Two modes:

- **Listen** — cards play automatically according to a **recipe** (which lines, in what order).
- **Mirror** — no auto-play. Play individual German sentences, record yourself repeating them,
  compare.

The app tracks one thing: **whether you have heard each word.** Long-term memorisation and recall
testing are done in Anki, which is outside this app.

---

## 2. Scope

### In scope

- Pack discovery from a user-chosen folder, with rescan
- Listen mode with recipes and line highlighting
- Mirror mode with recording
- Multi-pack sessions, saved and resumable
- Per-word "heard" progress, shown per pack
- "Also in" tags for words that appear in several packs

### Out of scope — do not build

- Pause. Tap replays.
- Spaced repetition, grading, recall testing, streaks, points.
- Background or lock-screen playback.
- Network of any kind: downloads, accounts, sync, analytics, crash reporting.
- iOS and web builds. Don't prevent them, don't build them.
- Starter content. First launch goes to folder selection.
- Deleting packs from inside the app.
- Colour-coding by article (der/die/das). On hold.
- Speaking grammar forms. Grammar is displayed only.

---

## 3. Platform and stack

- Flutter, Android first. The Flutter project is the repository root.
- **Minimum Android 10 (API 29)** — the primary device is a POCO F1 on Android 10.
- Packages: `sqflite` (plus `sqflite_common_ffi` for tests), `path_provider`, `just_audio`,
  `audio_session`, `saf_util` and `saf_stream` (folder access, chosen in A0; not `file_picker`),
  `shared_preferences`, `wakelock_plus`, `record`, `permission_handler`, and a JSON Schema
  validator (see 4.1).
- State management: keep it simple and consistent. Propose one in step A1 and justify it; don't
  mix approaches.

---

## 4. The pack contract

Packs are produced by the pipeline repository. The app never writes into a pack.

### 4.1 Schema

`schema/manifest.v2.schema.json` (JSON Schema 2020-12) defines a valid manifest. It is a copy from
the pipeline repository — **never edit it here**.

Validate every manifest against it at scan time. If no Dart package supports draft 2020-12 well
enough (in particular `if`/`then` and `additionalProperties: false`), say so in step A2's plan and
propose an alternative rather than silently skipping validation.

### 4.2 Pack folder

```
a1_k02/
├── manifest.json
├── a1_k02__der_freund__word.ogg
├── a1_k02__der_freund__translation.ogg
└── …
```

Folder name equals `pack_id`. Audio is Opus in `.ogg`.

### 4.3 Pack fields the app uses

| Field | Use |
|---|---|
| `pack_id` | Identity. `<level>_k<NN>` (textbook) or `<level>_nb<NN>` (notebook) |
| `level` | `a1`, `a2`, `b1`, `b2` |
| `kind` | `textbook` or `notebook` |
| `number` | Chapter or notebook number |
| `title` | **Optional.** Human label |
| `audio_format` | Reject the pack if the app can't play it (v1 plays `opus`) |
| `generated_at` | Detect that a pack changed |
| `cards` | The words |

**Display name.** If `title` exists, show it as the heading with `A1 · Chapter 2` beneath. Without a
title, `A1 · Chapter 2` (textbook) or `A1 · Notebook 3` (notebook) is the heading.

**Sort order everywhere:** level, then kind (textbook before notebook), then number.

### 4.4 Card fields

| Field | Notes |
|---|---|
| `id` | `<pack_id>__<key>` |
| `key` | The word's identity across packs. May carry a homonym suffix: `gehen` and `gehen_2` are **different meanings** — different words for progress and "also in" |
| `type` | `noun`, `verb`, `other` |
| `added_at` | When the word joined the pack |
| `word`, `translation` | Lines (4.6) |
| `grammar` | Nouns and verbs only (4.5) |
| `note` | Optional, e.g. `+ Dativ` |
| `tags` | Optional. Stored, not displayed in v1 |
| `examples` | List, possibly empty (4.7) |

### 4.5 Grammar

**Noun** — all fields optional:

| Field | Meaning |
|---|---|
| `article` | `der`, `die`, `das`, `der/die` (adjectival nouns like *der/die Kranke*), or `der/das` (nouns with two genders like *der/das Sandwich*) |
| `no_article` | `true` — the noun takes no article (*Fußball*) |
| `plural` | Full plural, e.g. `die Ärzte` |
| `no_plural` | `true` — there is no plural (*die Musik*) |
| `plural_only` | `true` — exists only in the plural (*die Leute*) |
| `feminine`, `feminine_plural` | Person nouns: *die Ärztin*, *die Ärztinnen* |
| `feminine_translation` | Present only when the English differs: *waitress* |

**Verb** — `present_3sg` (*er singt*), `perfect` (*hat gesungen*), both optional.

### 4.6 Lines

Every line is `{ "text", "audio", "spoken"? }`. **Display `text`. Never display `spoken`** — it is
what the voice read and exists only for audio generation. `audio` is a filename inside the pack
folder.

### 4.7 Examples

Each example has `n`, `form` (`base` / `plural` / `feminine`), `kind` (`statement` / `qa`) and
`origin` (`textbook` / `generated`).

- **statement** → `source` (German line), `target` (English line)
- **qa** → `question` and `answer`, each with `source` and `target`

`origin` is not displayed in v1.

---

## 5. Pack discovery

### 5.1 Folder selection

The user picks a root folder once. Each immediate subfolder that contains `manifest.json` is a
candidate pack. Other subfolders are ignored silently.

**Decided in A0: (a) read in place** (see `docs/A0_FINDINGS.md`). The folder is picked with the
Storage Access Framework and a persisted read permission is kept; manifests are read and clips
played from there, through `content://` URIs. Nothing is copied into app storage.

- Pick with `saf_util.pickDirectory` with a persistable permission. List with `saf_util.list`;
  read files with `saf_stream`.
- **Store the tree URI** (`…/tree/<id>`) in `shared_preferences`, not the
  `…/tree/<id>/document/<id>` form `pickDirectory` returns — the permission is held on the tree URI.
- **Picked a pack folder instead of the root.** If the chosen folder itself contains
  `manifest.json`, it is a single pack, not the folder that holds packs. Don't scan it as a root
  (it would find no packs, or the wrong ones); say that this looks like one pack and ask the user to
  pick the folder that contains their pack folders.

A0 was proven on both the POCO F1 (Android 10) and an Android 14 (API 34) emulator: pick folder →
read manifest → play an `.ogg` → relaunch → play again without re-picking; also after reboot and
app update.

### 5.2 Rescan

On launch and from a **Rescan** action. For each candidate pack:

1. Validate the manifest against the schema.
2. Check `pack_id` equals the folder name, `audio_format` is playable, and **every referenced clip
   exists**. List the pack folder **once** and compare names against the manifest's references.
   Never look clips up one at a time: through the storage framework that costs about 0.1–0.2 s per
   clip, minutes per chapter (A0).
3. **Any failure rejects the whole pack.** A pack with a missing clip would fail mid-session, where
   the user can't diagnose it.
4. Reconcile with the database:
   - new `pack_id` → insert pack and cards
   - known `pack_id`, different `generated_at` → replace its cards wholesale
   - known `pack_id`, same `generated_at` → nothing
   - known pack no longer found → mark unavailable, keep its rows
5. **Never touch progress** in any of these.

**Restart-safe.** Android can recreate the activity at any moment, restarting the Dart side (A0
finding 5). Each pack is reconciled in a **single database transaction**, so an interrupted rescan
leaves every pack either fully old or fully new; the next rescan completes the work.

Report: added, updated, unchanged, unavailable, rejected (with the reason for each rejection).

### 5.3 Stale access

If folder access is lost — moved, revoked, storage unmounted — prompt to re-select. **Never show an
empty library**, which reads as "my packs are gone".

- **Check the root folder itself**, not whether listing succeeds. A moved or deleted folder lists as
  empty, without an error, and its permission still reports as held (A0). Access is lost when the
  root doesn't `stat`, the persisted permission is gone, or access throws.
- **Offer *Try again* before re-selecting**, and keep the saved folder. Shortly after boot, shared
  storage can briefly look missing and then reappear intact (A0).

---

## 6. Data

`sqflite`. Define `onUpgrade` from the start.

```sql
CREATE TABLE packs (
  pack_id       TEXT PRIMARY KEY,
  level         TEXT NOT NULL,
  kind          TEXT NOT NULL,
  number        INTEGER NOT NULL,
  title         TEXT,
  card_count    INTEGER NOT NULL,
  audio_format  TEXT NOT NULL,
  available     INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL,
  generated_at  TEXT NOT NULL
);

CREATE TABLE cards (
  card_id                 TEXT PRIMARY KEY,
  pack_id                 TEXT NOT NULL,
  key                     TEXT NOT NULL,
  type                    TEXT NOT NULL,
  added_at                TEXT NOT NULL,
  has_base_statement      INTEGER NOT NULL,
  has_base_qa             INTEGER NOT NULL,
  has_plural_statement    INTEGER NOT NULL,
  has_plural_qa           INTEGER NOT NULL,
  has_feminine_statement  INTEGER NOT NULL,
  has_feminine_qa         INTEGER NOT NULL,
  content_json            TEXT NOT NULL
);
CREATE INDEX idx_cards_pack ON cards(pack_id);
CREATE INDEX idx_cards_key  ON cards(key);

CREATE TABLE progress (
  key             TEXT PRIMARY KEY,
  times_heard     INTEGER NOT NULL DEFAULT 0,
  first_heard_at  TEXT,
  last_heard_at   TEXT,
  times_recorded  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE session (
  id               INTEGER PRIMARY KEY CHECK (id = 1),
  mode             TEXT NOT NULL,     -- listen | mirror
  pack_ids_json    TEXT NOT NULL,     -- in selection order
  words            TEXT NOT NULL,     -- all | noun | verb | other
  focus            TEXT NOT NULL,     -- base | plural | feminine
  style            TEXT NOT NULL,     -- statement | qa
  qa_translate     TEXT NOT NULL,     -- both | question
  deck_order       TEXT NOT NULL,     -- sequential | shuffled
  card_mode        TEXT NOT NULL,     -- looped | continuous
  card_limit       INTEGER,           -- null = no limit
  unheard_first    INTEGER NOT NULL,
  card_order_json  TEXT NOT NULL,     -- resolved list of card_ids
  position         INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL,
  last_opened_at   TEXT NOT NULL
);
```

- The six `has_*` flags are computed at scan time so recipe filtering is a query, not JSON parsing.
- `content_json` is the card as it appears in the manifest, read whole to render.
- **`progress` is keyed by word key, with no foreign key and no cascade.** Rows for keys not
  currently present are ignored, and reattach when the word reappears.
- `session` is one row, replaced when a new session starts. It stores the **resolved card order**,
  not a random seed, so resuming is exact even if packs changed.
- Folder location, pause lengths, speed and keep-screen-on live in `shared_preferences`.

---

## 7. Progress

- A card counts as **heard** when its full recipe plays to the end in Listen mode. Replays count
  again. A card left early does not count.
- Progress is **per word key**, shared across packs: hearing *der Freund* in chapter 2 also counts in
  notebook 1.
- **Pack progress** = the pack's distinct keys heard at least once ÷ the pack's distinct keys.
- Each finished Mirror recording increments `times_recorded`. Stored, not displayed in v1.

---

## 8. "Also in"

For a card, other **available** packs containing the same key:

```sql
SELECT DISTINCT c.pack_id
FROM cards c JOIN packs p ON p.pack_id = c.pack_id
WHERE c.key = ? AND c.pack_id != ? AND p.available = 1
```

Shown as a small tag: *also in K2 · NB1*. Computed at display time, never stored.

---

## 9. Recipes (Listen mode)

A recipe is the ordered list of lines a card plays. The session's **words / focus / style** choices
select it.

| Style | Focus | Plays |
|---|---|---|
| statement | base | word → translation → base statement |
| statement | plural | word → translation → base statement → plural statement |
| statement | feminine | word → translation → base statement → feminine statement |
| qa | base | word → translation → base Q&A |
| qa | plural | word → translation → base Q&A → plural Q&A |
| qa | feminine | word → translation → base Q&A → feminine Q&A |

- A **statement** plays source, then target.
- A **Q&A** plays question source, question target, answer source, answer target. With
  `qa_translate: question`, the answer's English is skipped.
- Each recipe uses the **first** example matching each required form and kind.
- **Cards lacking a required example are excluded from the session**, never played partially.
  Plural focus contains only nouns with a plural example of the chosen style.
- **Words** filters by `type`. Focus is offered only when Words is `all` or `noun`; plural and
  feminine focus only ever match nouns.
- Recipes are **data**, not branches in the engine. Adding one must not touch engine code.

---

## 10. Sessions

### 10.1 Setup

Choose packs (multi-select, sort order from 4.3), then:

| Option | Values | Default |
|---|---|---|
| Mode | listen / mirror | listen |
| Words | all / nouns / verbs / other | all |
| Focus | base / plural / feminine | base |
| Style | statements / Q&A | statements |
| Q&A translation | question and answer / question only | question and answer |
| Deck order | in order / shuffled | in order |
| Card mode | looped / continuous | looped |
| Card limit | none / a number | none |
| Unheard first | on / off | off |

- **In order** plays packs in the order selected, each pack's cards in manifest order.
  **Shuffled** mixes cards from all selected packs.
- Shuffle happens **once**, at creation. The resolved order is saved; never reshuffle mid-session.
- A word in two selected packs appears twice. Accepted.
- **Unheard first** moves unheard words to the front (keeping the deck order within each group).
  **Card limit** then truncates. Together they make short sessions of new material.
- Mode Mirror hides options that don't apply (card mode, Q&A translation).

### 10.2 Position and resume

- Position **advances when a card is left, however it's left** — auto-advance or swipe. Written to
  the database on every advance. Replay never moves it.
- On launch, if a session exists, prompt before anything else, showing its packs, main options and
  position (*47 of 90*): **Resume** or **New session**.
- On resume, drop card ids that no longer exist. If more than half are gone, go to setup with an
  explanation instead.

### 10.3 End card

After the last card: **Restart** (same order), **Reshuffle** (new order, same options), **Change
selection**. Reached by swiping like any card; not a modal.

---

## 11. Listen playback engine

**Build and test this before any UI.** Pure Dart.

### 11.1 Interface

```dart
abstract class ClipPlayer {
  Future<void> play(String uri); // completes when the clip finishes OR when stop() is called
  Future<void> stop();
}
```

The real implementation wraps `just_audio`. A `FakeClipPlayer` backed by timers is used for all
engine tests. The engine never imports `just_audio`.

Clips are addressed by **URI** — `content://` under the storage approach chosen in A0, not file
paths.

**Preload the next clip.** Loading a clip from the pack folder takes about 60–170 ms, and 450–550 ms
for the first clip after install or reboot (A0); unhidden, that lands inside `play()` and lengthens
every pause. The real player prepares the next clip ahead of time so `play()` starts promptly. How
the engine tells the player which clip is next is designed in A3's plan; it must not add an `await`
to the engine without a generation check after it (11.3), and must not change `play`/`stop`
semantics.

### 11.2 Algorithm

```
gen = 0

cancel():
  gen++; player.stop(); timer?.cancel()

playCard(card, myGen):
  loop:
    for step in recipe.steps(card):
      if myGen != gen: return
      highlight(step)
      await player.play(step.clipUri)
      if myGen != gen: return
      await sleep(pauseAfter(step))
      if myGen != gen: return
    markHeard(card.key)                  # the full recipe completed
    if cardMode == looped: continue
    await sleep(cardGap)
    if myGen != gen: return
    advance(); return

onSwipe():     cancel(); advance()
onTapReplay(): cancel(); playCard(current, gen)
```

### 11.3 Why every check exists — read before editing

**Check the generation after every `await`. Never remove one.**

An `await` doesn't block. It pauses this function while the app keeps handling touches. If the user
swipes during a pause, the swipe handler runs immediately: it bumps `gen` and advances to the next
card. But the paused function is still waiting. When its clip or timer finishes, it resumes and runs
its next line — which may be `advance()`. Result: two advances from one swipe, a card flashes past,
and the bug appears as an intermittent "sometimes it skips a card".

`cancel()` can't stop code that is already running. It can only leave a flag for that code to check
when it wakes. Every `await` is a point where the world may have changed.

### 11.4 Pauses

Inserted by the app. Settings, with defaults:

| After | Default |
|---|---|
| German headword | 800 ms |
| English translation | 1000 ms |
| German sentence line | 1500 ms |
| English sentence line | 800 ms |
| Between cards | 2000 ms |

The pause after a German sentence is deliberately longest: it's where the learner tries to
understand before the English arrives.

### 11.5 Other behaviour

- **Highlighting** follows the step that is currently playing.
- **Card mode** can change mid-session; it takes effect at the end of the current pass.
- **Speed** 0.75× / 1× / 1.25× applies to clips, not pauses.
- **Audio session**: plays with the silent switch on; pauses for calls and resumes after; ducks for
  short interruptions.
- **Wakelock** (`wakelock_plus`): held while a session screen is open; released on leaving it and
  when the app goes to the background.
- **App backgrounded**: stop playback; on return, restart the current card from its first line.
- **Restart-safe sessions.** Android can recreate the activity and restart the Dart side at any
  moment (A0). Nothing needed to resume may live only in memory: position is already written on
  every advance (10.2), and after a restart the session resumes at the saved position and the
  current card restarts from its first line, as when backgrounded. A card interrupted this way is
  not marked heard.

### 11.6 Required tests — write these first

| Scenario | Expected |
|---|---|
| Continuous, card completes | Heard once; exactly one advance |
| Swipe mid-clip | Audio stops; exactly one advance; not marked heard |
| Swipe during a pause between lines | Exactly one advance; the stale timer does nothing |
| Swipe during the gap between cards | Exactly one advance, not two |
| Tap replay mid-card | Restarts from the first line; position unchanged |
| Tap replay during a pause | Restarts from the first line; pending advance cancelled |
| Looped mode | Repeats; heard on each full pass; position unchanged |
| Card mode switched mid-card | Applies at end of pass; no double advance |
| Five swipes within 200 ms | Exactly five advances; no audio left playing |
| Swipe on the last card | Lands on the end card |

**If the pause-swipe or rapid-swipe test fails, a generation check has been removed or misplaced.**

---

## 12. Mirror mode

- No auto-play, no auto-advance. Swipe moves between cards.
- The card shows word, meaning and grammar, then **boxes**:
  - Style *statements*: the first two base statements (one box if only one exists).
  - Style *Q&A*: the base question box and the base answer box.
- Each box shows German and English text with **Play** (German clip) and **Record**. **Play mine**
  appears once a recording exists.
- Any play or record action cancels whatever else is playing — same generation-counter rule.
- Recordings are **temporary**: replaced by the next attempt, deleted when leaving the card.
- Microphone permission is requested on the **first** Record, not at launch. If refused, Record
  explains why it can't work and how to allow it.
- Audio session switches to play-and-record while in Mirror mode.
- A finished recording increments `times_recorded`.
- Cards lacking the required examples are excluded.

---

## 13. Card display

- Headword large. For nouns the article is part of the headword text.
- **Grammar line** beneath:
  - noun: plural — or *plural only* / *no plural*; *no article* when `no_article`; then
    `feminine` with `feminine_translation` when present (*die Kellnerin · waitress*)
  - verb: `present_3sg · perfect`, whichever exist
  - `note` for any type (*+ Dativ*)
- Examples as the recipe plays them, German above English, active line highlighted.
- *Also in* tag when applicable.
- Session position in the header as text: *Card 23 of 90*.

**Gestures:** swipe either way → next card; tap → replay (Listen). Both directions do the same.
Left and right are reserved for possible future use — don't bind anything else to them.

---

## 14. Settings

- Pause lengths (11.4)
- Speed: 0.75× / 1× / 1.25×
- Keep screen on during sessions (default on)
- Change folder, Rescan

---

## 15. Build Plan

| Step | Build | Done when |
|---|---|---|
| **A0** | Storage and playback spike (5.1) | On the POCO F1 (Android 10) and an Android 14 emulator: pick folder → read manifest → play an `.ogg` → relaunch → play again without re-picking. Approach chosen with trade-offs. **Stop for review** |
| **A1** | `flutter create`, theme tokens from DESIGN.md, database schema, data-access layer + tests | Schema created on first launch; data-access tests pass on desktop via `sqflite_common_ffi` |
| **A2** | Schema validation, rescan and reconcile, pack list screen | With the fixture packs: valid packs load; `a1_k03` rejected for a missing clip; `notes` ignored; updating a pack keeps progress; unavailable pack stays listed |
| **A3** | Playback engine + `FakeClipPlayer`; tests from 11.6 written first | All 11.6 tests pass |
| **A4** | Listen mode, base-statement recipe, highlighting, swipe and replay | Plays on a device with correct highlighting; swipe and replay interrupt cleanly |
| **A5** | Session setup, resume, end card, card limit, unheard first | Multi-pack sessions build; resume works after force-closing the app |
| **A6** | Progress, pack progress, "also in" | Hearing `der_freund` in `a1_k02` counts in `a1_nb01`; `gehen` and `gehen_2` tracked separately |
| **A7** | All recipes and filters | Every words/focus/style combination; cards lacking examples excluded |
| **A8** | Mirror mode | Record, play back, discard on leaving the card; permission refusal handled |

---

## 16. Fixture packs

`tool/make_fixture_pack.py` generates test packs under `test/fixtures/packs/` from definitions
inside the script, and validates each manifest against the schema. Clips are short tones — one pitch
for German, another for English — whose length follows the text length, so playback order and
highlighting are observable. Requires Python 3 and `ffmpeg` with `libopus`; the generated packs are
also committed, so tests run without regenerating.

| Pack | Purpose |
|---|---|
| `a1_k02` | Valid textbook pack with title: nouns, a verb, a textbook Q&A |
| `a1_nb01` | Valid notebook pack **without** title. Shares `der_freund` with `a1_k02`; has `gehen` and `gehen_2`, a plural-only noun, a no-article noun |
| `a1_k03` | **Invalid**: one referenced clip is missing. Must be rejected whole |
| `notes/` | No manifest. Must be ignored silently |

Once the pipeline produces real packs, test against those as well.

---

## 17. Open decisions

| Question | Position |
|---|---|
| Storage approach | **Decided in A0:** (a) read in place, `saf_util` + `saf_stream` (5.1) |
| Clip fails to load mid-session (e.g. files removed from the folder after a scan) | **Provisional (Claude, autonomous run, 2026-09-24; Ian to confirm):** the card stops at that line, isn't counted as heard and doesn't advance; the status line says so and suggests a rescan or a swipe (STATUS, Decisions) |
| Colour-coding by article | On hold |
| Displaying Mirror recording counts | Undecided |
| iOS | Later. Opus may need `.caf` on iOS; `audio_format` already allows for it |
