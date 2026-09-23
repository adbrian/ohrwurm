#!/usr/bin/env python3
"""Generate fixture packs for Ohrwurm app tests.

Writes test/fixtures/packs/ with:
  a1_k02/   valid textbook pack, with title
  a1_nb01/  valid notebook pack, without title (shares a key with a1_k02; has gehen + gehen_2)
  a1_k03/   INVALID: one referenced clip is deleted after generation
  notes/    no manifest; must be ignored by the app

Clips are short sine tones in Opus/.ogg. German lines use one pitch, English another, and each
clip's length follows its text length, so playback order and highlighting are observable.

Requires Python 3.9+ and ffmpeg with libopus. If the `jsonschema` package is installed, every
manifest is validated against schema/manifest.v2.schema.json.

Usage (from the repository root):
    python3 tool/make_fixture_pack.py
"""
from __future__ import annotations

import copy
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test" / "fixtures" / "packs"
SCHEMA = ROOT / "schema" / "manifest.v2.schema.json"

VOICES = {"de": "de-DE-KatjaNeural", "en": "en-GB-SoniaNeural"}
T0 = "2026-09-20T10:00:00Z"
T1 = "2026-09-23T14:30:00Z"

# Pack definitions: line dicts carry text (and optional spoken); audio names are filled in below.
PACKS = [
    {
        "pack_id": "a1_k02", "level": "a1", "kind": "textbook", "number": 2,
        "title": "Freunde, Kollegen und ich",
        "cards": [
            {
                "key": "der_freund", "type": "noun",
                "word": {"text": "der Freund"}, "translation": {"text": "friend"},
                "grammar": {"article": "der", "plural": "die Freunde", "feminine": "die Freundin",
                            "feminine_plural": "die Freundinnen",
                            "feminine_translation": "female friend, girlfriend"},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "generated",
                     "source": {"text": "Mein Freund kommt aus Berlin."},
                     "target": {"text": "My friend comes from Berlin."}},
                    {"form": "base", "kind": "qa", "origin": "generated",
                     "question": {"source": {"text": "Hast du einen guten Freund?"},
                                  "target": {"text": "Do you have a good friend?"}},
                     "answer": {"source": {"text": "Ja, mein Freund heißt Thomas."},
                                "target": {"text": "Yes, my friend is called Thomas."}}},
                    {"form": "plural", "kind": "statement", "origin": "generated",
                     "source": {"text": "Meine Freunde wohnen in München."},
                     "target": {"text": "My friends live in Munich."}},
                    {"form": "feminine", "kind": "statement", "origin": "generated",
                     "source": {"text": "Meine Freundin tanzt gern."},
                     "target": {"text": "My girlfriend likes to dance."}},
                ],
            },
            {
                "key": "singen", "type": "verb",
                "word": {"text": "singen"}, "translation": {"text": "to sing"},
                "grammar": {"present_3sg": "er singt", "perfect": "hat gesungen"},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "textbook",
                     "source": {"text": "Sie singt sehr gern."},
                     "target": {"text": "She likes singing very much."}},
                ],
            },
            {
                "key": "heissen", "type": "verb",
                "word": {"text": "heißen"},
                "translation": {"text": "to be named / called", "spoken": "to be named, or called"},
                "grammar": {"present_3sg": "er heißt", "perfect": "hat geheißen"},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "generated",
                     "source": {"text": "Wie heißt die neue Kollegin?"},
                     "target": {"text": "What is the new colleague called?"}},
                ],
            },
            {
                "key": "gern", "type": "other",
                "word": {"text": "gern"}, "translation": {"text": "gladly"},
                "examples": [
                    {"form": "base", "kind": "qa", "origin": "textbook",
                     "question": {"source": {"text": "Liest du gern?"},
                                  "target": {"text": "Do you like to read?"}},
                     "answer": {"source": {"text": "Ja, sehr gern."},
                                "target": {"text": "Yes, very much."}}},
                ],
            },
        ],
    },
    {
        "pack_id": "a1_nb01", "level": "a1", "kind": "notebook", "number": 1,
        # no title on purpose
        "cards": [
            {
                "key": "der_freund", "type": "noun",
                "word": {"text": "der Freund"}, "translation": {"text": "friend"},
                "grammar": {"article": "der", "plural": "die Freunde"},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "generated",
                     "source": {"text": "Ich treffe heute einen Freund."},
                     "target": {"text": "I'm meeting a friend today."}},
                ],
            },
            {
                "key": "die_leute", "type": "noun",
                "word": {"text": "die Leute"}, "translation": {"text": "people"},
                "grammar": {"plural_only": True},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "generated",
                     "source": {"text": "Die Leute sind sehr nett."},
                     "target": {"text": "The people are very nice."}},
                ],
            },
            {
                "key": "fussball", "type": "noun",
                "word": {"text": "Fußball"}, "translation": {"text": "football"},
                "grammar": {"no_article": True, "no_plural": True},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "textbook",
                     "source": {"text": "Er spielt gern Fußball."},
                     "target": {"text": "He likes to play football."}},
                ],
            },
            {
                "key": "gehen", "type": "verb",
                "word": {"text": "gehen"}, "translation": {"text": "to go"},
                "grammar": {"present_3sg": "er geht", "perfect": "ist gegangen"},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "textbook",
                     "source": {"text": "Gehst du gern ins Kino?"},
                     "target": {"text": "Do you like going to the cinema?"}},
                    {"form": "base", "kind": "qa", "origin": "textbook",
                     "question": {"source": {"text": "Gehen wir ins Kino?"},
                                  "target": {"text": "Are we going to the cinema?"}},
                     "answer": {"source": {"text": "Nein, das geht leider nicht."},
                                "target": {"text": "No, unfortunately that doesn't work."}}},
                ],
            },
            {
                "key": "gehen_2", "type": "verb",
                "word": {"text": "gehen"},
                "translation": {"text": "here: to be okay", "spoken": "to be okay"},
                "grammar": {"present_3sg": "es geht", "perfect": "ist gegangen"},
                "examples": [
                    {"form": "base", "kind": "qa", "origin": "textbook",
                     "question": {"source": {"text": "Hörst du gern Musik?"},
                                  "target": {"text": "Do you like listening to music?"}},
                     "answer": {"source": {"text": "Es geht so."},
                                "target": {"text": "It's okay."}}},
                ],
            },
            {
                "key": "in", "type": "other",
                "word": {"text": "in"}, "translation": {"text": "in"}, "note": "+ Dativ",
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "generated",
                     "source": {"text": "Ich wohne in der Stadt."},
                     "target": {"text": "I live in the city."}},
                ],
            },
        ],
    },
    {
        "pack_id": "a1_k03", "level": "a1", "kind": "textbook", "number": 3,
        "title": "In der Stadt",
        "cards": [
            {
                "key": "die_stadt", "type": "noun",
                "word": {"text": "die Stadt"}, "translation": {"text": "city"},
                "grammar": {"article": "die", "plural": "die Städte"},
                "examples": [
                    {"form": "base", "kind": "statement", "origin": "generated",
                     "source": {"text": "Die Stadt ist sehr schön."},
                     "target": {"text": "The city is very beautiful."}},
                ],
            },
        ],
    },
]

# Clips deleted after generation, to make a pack invalid.
DELETE_AFTER = {"a1_k03": ["a1_k03__die_stadt__ex1_src.ogg"]}


def build_manifest(pack: dict) -> tuple[dict, list[tuple[str, str, str]]]:
    """Return a schema-shaped manifest and a list of (filename, text, lang) clips to generate."""
    pid = pack["pack_id"]
    clips: list[tuple[str, str, str]] = []
    manifest = {
        "schema_version": 2,
        "pack_id": pid,
        "level": pack["level"],
        "kind": pack["kind"],
        "number": pack["number"],
    }
    if pack.get("title"):
        manifest["title"] = pack["title"]
    manifest.update({
        "source_lang": "de", "target_lang": "en", "audio_format": "opus",
        "voices": VOICES, "created_at": T0, "generated_at": T1, "cards": [],
    })

    def line(obj: dict, card_id: str, clip: str, lang: str) -> dict:
        out = copy.deepcopy(obj)
        name = f"{card_id}__{clip}.ogg"
        out["audio"] = name
        clips.append((name, obj.get("spoken", obj["text"]), lang))
        return out

    for c in pack["cards"]:
        cid = f"{pid}__{c['key']}"
        card = {"id": cid, "key": c["key"], "type": c["type"], "added_at": T0,
                "word": line(c["word"], cid, "word", "de"),
                "translation": line(c["translation"], cid, "translation", "en")}
        if "grammar" in c:
            card["grammar"] = c["grammar"]
        if "note" in c:
            card["note"] = c["note"]
        card["examples"] = []
        for n, ex in enumerate(c["examples"], start=1):
            e = {"n": n, "form": ex["form"], "kind": ex["kind"], "origin": ex["origin"]}
            if ex["kind"] == "statement":
                e["source"] = line(ex["source"], cid, f"ex{n}_src", "de")
                e["target"] = line(ex["target"], cid, f"ex{n}_tgt", "en")
            else:
                e["question"] = {"source": line(ex["question"]["source"], cid, f"ex{n}_q_src", "de"),
                                 "target": line(ex["question"]["target"], cid, f"ex{n}_q_tgt", "en")}
                e["answer"] = {"source": line(ex["answer"]["source"], cid, f"ex{n}_a_src", "de"),
                               "target": line(ex["answer"]["target"], cid, f"ex{n}_a_tgt", "en")}
            card["examples"].append(e)
        manifest["cards"].append(card)
    return manifest, clips


def make_tone(path: Path, text: str, lang: str) -> None:
    seconds = min(max(len(text) * 0.06, 0.4), 2.5)
    freq = 440 if lang == "de" else 660
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
         "-f", "lavfi", "-i", f"sine=frequency={freq}:duration={seconds:.2f}",
         "-c:a", "libopus", "-b:a", "32k", "-ac", "1", str(path)],
        check=True,
    )


def validate(manifest: dict) -> None:
    try:
        import jsonschema  # type: ignore
    except ImportError:
        print("  (jsonschema not installed; skipping schema validation)")
        return
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator(schema).validate(manifest)
    print("  schema: valid")


def main() -> int:
    if shutil.which("ffmpeg") is None:
        print("ffmpeg not found", file=sys.stderr)
        return 1
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    for pack in PACKS:
        pid = pack["pack_id"]
        print(f"{pid}")
        manifest, clips = build_manifest(pack)
        validate(manifest)
        d = OUT / pid
        d.mkdir()
        (d / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        for name, text, lang in clips:
            make_tone(d / name, text, lang)
        for name in DELETE_AFTER.get(pid, []):
            (d / name).unlink()
            print(f"  deleted {name} (pack intentionally invalid)")
        print(f"  {len(manifest['cards'])} cards, {len(clips)} clips")

    notes = OUT / "notes"
    notes.mkdir()
    (notes / "readme.txt").write_text("Not a pack. The app must ignore this folder.\n")
    print("notes/ (no manifest)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
