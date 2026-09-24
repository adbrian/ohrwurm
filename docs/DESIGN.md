# Ohrwurm — Design

Visual system and screens. Behaviour is in `docs/APP_SPEC.md`; where they differ, the spec wins.

---

## The idea

**A transcript that lights up as it speaks.** The whole card — word, meaning, grammar, example
sentences — is visible and legible for the whole time it plays. Nothing moves, appears, reflows or
resizes during playback. **Only the highlight moves**, from line to line, following the audio.

Two jobs for the screen, at a glance: *which line is sounding now*, and *how much of this card is
left*.

**Interruption is normal.** The user swipes mid-line constantly. Every state must look intentional
when cut off: no half-finished animations, no loading spinners, no layout shifts when audio stops.

---

## Visual system

A dark, quiet palette with confident, chunky shapes. The rule for combining them:

> **Quiet colour, bold shapes, no filled blocks.**

### Colour tokens

Define these once in the theme; never hardcode colours in widgets. Starting values — adjust on a
real screen.

| Token | Value | Use |
|---|---|---|
| `bg` | `#0E0E13` | App background |
| `surface` | `#17171F` | Cards, tiles |
| `surfaceRaised` | `#1F1F29` | Highlighted line background base |
| `divider` | `#2C2C38` | Borders at rest, rules |
| `text` | `#ECECF1` | Primary text, German |
| `neutral300` | `#B4B4C2` | English text |
| `neutral400` | `#8E8E9E` | Secondary text |
| `neutral500` | `#6C6C7C` | Meta text |
| `neutral600` | `#4E4E5C` | Disabled |
| `accent` | `#9184D9` | Lines, marks, active states |
| `accent300` | `#B7AEF0` | Numeric values, emphasis |
| `accent700` | `#6A5FB3` | Dimmed accent, completed |
| `accent800` | `#4F4787` | Subtle accent borders |
| `accent900` | `#2E2A4D` | Accent-tinted tile backgrounds |

**The accent is a line, a mark or a soft glow — never a filled button or block.** The only accent
backgrounds are low-opacity tints (around 15%) and the `accent900` tile tint.

### Shape

- **Borders:** 2 px on interactive elements, 1 px on dividers and rules.
- **Radii:** 16 px cards, 12 px tiles and buttons, fully rounded pills for toggles and segmented
  controls.
- **Buttons are outlined only.** Primary: 2 px accent border, accent text. Secondary: 2 px divider
  border, text colour. Ghost: text only.
- Spacing on a compact scale: 4, 8, 12, 16, 24, 32.

### Type

- **Inter** throughout (bundle it; no network fonts).
- **German text weight 500. English text weight 400.** That is the only visual distinction between
  the languages — no flags, no colour coding, no labels.
- Numbers that update in place (position, slider values) use tabular figures.

### Icons

Phosphor, stroked (regular weight), 16–20 px, drawn in the current text colour. Bundled as a font,
like Inter.

---

## Screens

### 1. First launch

No packs exist yet.

- Rounded tile with an accent-outlined headphone icon.
- Heading: *Let's get your ears working.*
- One paragraph: you see a word and its sentences, you hear them read aloud, you read along and
  swipe. No typing, no network.
- Three numbered lines (numbers in accent): make packs on your computer; copy the pack folders onto
  this phone; show Ohrwurm where you put them.
- Primary button: **Choose folder**.

### 2. Folder and rescan result

After choosing a folder, and whenever Rescan runs.

- A back arrow, top left, to the library. The system back does the same.
- The folder location in a surface tile.
- One row per subfolder, and one per known pack that's no longer found: a status disc (12 px), the
  pack's display name, and a detail line. A titled pack's detail line starts with its label, so the
  title has *A1 · Chapter 1* beneath: *A1 · Chapter 1 · added · 200 words*.
  - Filled accent disc — *added · 80 words* / *updated · 80 words*
  - Hollow neutral disc (1.5 px `neutral400` ring) — *unchanged*
  - Ringed neutral disc (3 px `neutral400` ring) — *not loaded · 2 audio files missing*; a known
    pack adds *· progress kept*. Also a known pack whose folder is gone: *not found · progress kept*
  - Neutral-600 hollow disc (1.5 px `neutral600` ring) — *no manifest · skipped*
- Verdict panel:
  - Everything fine: accent-tinted panel, *2 packs ready.* Button: **Choose packs**.
  - Something rejected: neutral-bordered panel, *One pack wasn't loaded. Nothing else changed.*
    If the same rescan added or updated packs: *One pack wasn't loaded. The rest are ready.*
    (*2 packs weren't loaded. …* for more.) Button: **Rescan**.
  - No packs and nothing rejected: neutral-bordered panel, *No packs in this folder yet. Copy your
    pack folders into it, then rescan.* Button: **Rescan**.

This screen carries the product's key promise: **a broken pack is rejected whole and visibly, never
loaded half-way.**

### 3. Resume prompt

Shown at launch when a session exists, before anything else.

- Accent kicker: *PICK UP WHERE YOU LEFT OFF*
- A surface tile: pack names, *shuffled · loop · statements*, and *47 of 90* in large tabular
  figures with a thin accent progress bar.
- **Resume** (primary), **New session** (ghost).
- If most of the session's cards are gone: a neutral panel, *Some packs aren't on this phone
  anymore*, and only **Choose packs**.

### 4. Session setup

The main entry point.

- **Pack list**, multi-select, sorted by level → textbook before notebook → number. Each pack is a
  card:
  - heading: title, or *A1 · Chapter 2* / *A1 · Notebook 3* when there's no title
  - meta line: *A1 · Chapter 2 · 80 words* (omit the repeat when it's already the heading)
  - pack progress as a thin bar with *34 / 80 heard*
  - selected: 2 px accent border and a small accent check; never a fill
  - unavailable: neutral-600, tag *Not found* — or *Not loaded* when the last rescan rejected it —
    not selectable, still shown
- No packs yet: the pack list is the line *No packs in this folder yet. Copy your pack folders into
  it, then rescan.*
- **Options** below, as pill segmented controls: Mode, Words, Focus (only when relevant), Style,
  Q&A translation (only with Q&A), Deck order, Card mode (Listen only); a card-limit stepper; an
  *Unheard first* switch.
- Footer: live count, *3 packs · 164 cards*, and **Start** (primary), disabled until a pack is
  chosen. If the options exclude every card, the count reads *0 cards* with one line explaining which
  option to change.

### 5. Listen card — the product

Full-height card on `surface` between a slim header and a control row.

**Header**
- Back, the session's pack names, and *Card 23 of 90 · shuffled* beneath.
- A pill toggle **Loop** on the right: accent border when looped, divider border when continuous.

**Card progress** — a row of thin segments directly under the header, **one per line in the
recipe**. The finished segments are `accent700`, the current one fills in `accent` as it plays,
upcoming ones are `divider`. This shows position within the card — a card is about 20 seconds, and
that's the wait the user sits through. There is no progress bar for the whole session.

**Card body, top to bottom**
- The headword, 30 px, weight 500.
- The translation, 15 px.
- The grammar line, 13 px, `neutral400`: *die Ärzte · die Ärztin* or *er singt · hat gesungen* or
  *+ Dativ*.
- *Also in K2 · NB1* as a small outlined tag, when applicable.
- A rule, fading out at both ends.
- The example lines for this recipe: German above English, 15 px, 16 px between examples, 4 px
  within one. A Q&A shows as question pair, then answer pair.

**Active line**
- A 2 px accent mark in the left gutter, gently pulsing (opacity 0.45 → 1, about 1.1 s).
- An accent tint (about 15%) behind the line, bleeding slightly into the gutter.
- Active text: full `text`. Already played: `neutral400`. Not yet played: `neutral500`.
- Transitions: 250 ms, **colour and background only — never position or size.**

**Status line**, pinned to the card's bottom: a small dot (pulsing accent while a line plays, steady
dimmed accent during a pause) and one line of copy:
- *Listening…*
- *Your turn — understand it before the English* — during the long pause after a German sentence
- *Looping — swipe when you're ready* — in the gap, looped mode
- *Moving on…* — in the gap, continuous mode

**Controls below the card:** **Again** (secondary, restarts the card) and **Next** (secondary). No
pause button. A small hint line beneath: *Swipe either way for the next card · tap to replay*.

**Swipe:** the card follows the finger, tilting slightly (about `dx / 42` degrees) and fading a
little; past about 90 px it flies off and the next card arrives. Both directions do the same thing.

### 6. Replay

Tapping restarts at the first line: the progress segments reset, the highlight jumps to the
headword, the status reads *Replaying…* for about a second. Nothing else changes.

### 7. Mirror card

Same header and card body as Listen, without the line-progress segments and without auto-play.

Below the grammar line, **two boxes**, each a surface tile with a 1 px divider border:
- German line (weight 500), English line beneath.
- A row of controls: **Play** and **Record**. After a recording exists, **Play mine** appears.
- While recording: the Record control becomes an accent-outlined *Stop* with a small elapsed-time
  counter; the box border turns accent.
- While playing either voice: the box's German line takes the active-line treatment.

With Q&A style, the boxes are labelled *Question* and *Answer* in small `neutral500` caps.

Hint line: *Swipe for the next card*.

### 8. End card

Arrived at by swiping past the last card — a card in the deck, not a modal.

- Accent kicker: *SESSION DONE*
- Heading: *That was a solid run.*
- A tile: pack names, the session options, *90 cards*.
- **Restart** (primary), **Reshuffle** (secondary), **Change selection** (ghost).

No statistics — they aren't tracked. Don't design for numbers that don't exist.

### 9. Settings

- **PAUSES** — five sliders, each with a label, a tabular value in `accent300`, and one line of
  rationale. The German-sentence pause gets the most words: *The pause that does the teaching.
  Understand it before the English arrives.*
- **SPEED** — segmented: 0.75× / 1× / 1.25×.
- **Keep screen on during sessions** — pill switch.
- **Packs** — the current folder, **Rescan**, **Change folder**.

---

## Copy

Warm, plain, second person, never chirpy. Talk about what the user is doing (*Looping — swipe when
you're ready*). Talk about failure in terms of what was protected (*Nothing else changed*). No
exclamation marks, no emoji, no streaks, points or gamified language.

---

## Don't

- Don't animate position or size of anything while audio plays.
- Don't fill buttons or blocks with the accent. No gradients.
- Don't show a progress bar for the whole session.
- Don't colour-code der/die/das. It's on hold.
- Don't show `spoken` text, `origin`, or `tags`.
- Don't add pause controls. Tap is replay.
- No confetti, mascots, card stacks, cover flow, or 3D effects.
- No language flags or country colours.
- Nothing that implies a network: no sync, account, sharing or leaderboard affordances.
