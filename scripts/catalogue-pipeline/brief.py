#!/usr/bin/env python3
"""brief.py - daily 15-candidate brief generator for the Wedding Player catalogue.

Writes a dated brief into the Google Drive _candidates/ staging area:
  <drive>/_candidates/YYYY-MM-DD/brief.md      (Suno-ready prompt cards)
  <drive>/_candidates/YYYY-MM-DD/brief.json    (machine-readable sidecar)

Composition per day (15 candidates):
  4 PRELUDE, 4 PROCESSIONAL, 4 SIGNING, 3 RECESSIONAL
  Of those 15:
    - 2 are public-domain classics (rotating list)
    - 3 are under-represented genres (rotating list)
    - 10 are mainstream wedding styles (rotating list)

Each candidate gets a slug `cand_YYYY-MM-DD_NN` that promotes to wp_NNN
only on approval (review.py allocates the real id).

Idempotent: re-running for the same day overwrites the brief.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import random
from dataclasses import dataclass
from pathlib import Path

DRIVE_DEFAULT = Path.home() / "Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets"

CATEGORIES = ["PRELUDE", "PROCESSIONAL", "SIGNING", "RECESSIONAL"]
DAILY_CATEGORY_MIX = ["PRELUDE"] * 4 + ["PROCESSIONAL"] * 4 + ["SIGNING"] * 4 + ["RECESSIONAL"] * 3

# ---------------------------------------------------------------------------
# Pools
# ---------------------------------------------------------------------------
# Each pool entry is (style, instrumentation, mood, bpm_range, vocal, public_domain, notes).

@dataclass
class StyleSpec:
    style: str
    instrumentation: str
    mood: str
    bpm: str
    vocal: bool = False
    public_domain: bool = False
    notes: str = ""

# Public-domain classics - AI-re-recorded. Composition is PD; performance is ours.
PD_CLASSICS = [
    StyleSpec("Pachelbel Canon in D", "string quartet", "stately, hopeful", "60-66", public_domain=True,
              notes="Faithful arrangement, ~3 min."),
    StyleSpec("Wagner Bridal Chorus", "pipe organ + soft brass", "ceremonial, processional", "72-80", public_domain=True,
              notes="Traditional 'Here Comes the Bride' melody."),
    StyleSpec("Mendelssohn Wedding March", "full orchestra", "triumphant, recessional", "100-110", public_domain=True,
              notes="The classic exit march."),
    StyleSpec("Bach Jesu Joy of Man's Desiring", "piano + soft strings", "serene, devotional", "60-66", public_domain=True),
    StyleSpec("Clarke Trumpet Voluntary", "trumpet + organ", "regal, joyful", "80-88", public_domain=True,
              notes="aka Prince of Denmark's March."),
    StyleSpec("Schubert Ave Maria", "harp + solo violin", "sacred, tender", "60-72", public_domain=True,
              notes="Instrumental - no vocals."),
    StyleSpec("Bach Air on the G String", "string ensemble", "soaring, contemplative", "54-60", public_domain=True),
    StyleSpec("Handel Hornpipe (Water Music)", "baroque orchestra", "bright, ceremonial", "92-100", public_domain=True),
]

# Under-represented genres - push the catalogue beyond the safe centre.
ROTATING_GENRES = [
    StyleSpec("Gospel Choir Wedding Hymn", "full gospel choir + piano + Hammond organ", "uplifting, soulful", "68-76", vocal=True),
    StyleSpec("Celtic Wedding", "Irish whistle + Celtic harp + bodhran", "lyrical, hopeful", "70-80"),
    StyleSpec("Jazz Combo Ceremony", "upright bass + piano + brushed drums + muted trumpet", "warm, intimate", "70-84"),
    StyleSpec("Latin Acoustic", "nylon-string guitar + cajon + light percussion", "romantic, sun-warmed", "76-88"),
    StyleSpec("Indian Classical Fusion", "sitar + tabla + bansuri + soft pads", "graceful, contemplative", "60-72"),
    StyleSpec("Choral Sacred", "mixed SATB choir a cappella", "reverent, glowing", "60-68", vocal=True,
              notes="Wordless ahs/oohs only - no specific language."),
    StyleSpec("World Percussion Processional", "frame drum + kalimba + low strings", "earthy, anticipatory", "80-92"),
    StyleSpec("Ambient Electronic", "warm synth pads + subtle arpeggio + soft piano", "dreamlike, modern", "70-82"),
    StyleSpec("Indie Folk Acoustic", "fingerpicked acoustic guitar + soft mandolin + cello", "tender, hand-written", "72-84"),
    StyleSpec("Country Wedding", "acoustic guitar + dobro + light steel + brush kit", "warm, plain-spoken", "76-88"),
    StyleSpec("R&B Wedding Ballad", "Rhodes piano + sub bass + soft strings + light vocal", "smooth, devoted", "62-72", vocal=True),
]

# Mainstream wedding styles - the safe centre, rotated to avoid dupes.
MAINSTREAM = [
    StyleSpec("Cinematic Orchestral", "full strings + soft horns + harp + light timpani", "sweeping, romantic", "72-84"),
    StyleSpec("Acoustic Fingerstyle Guitar", "solo steel-string acoustic guitar", "gentle, contemplative", "70-80"),
    StyleSpec("Light Jazz Piano", "solo grand piano with subtle bass", "warm, conversational", "76-88"),
    StyleSpec("Modern Classical", "piano + cello + violin", "luminous, neoclassical", "66-76"),
    StyleSpec("Vocal Ballad", "piano + acoustic guitar + tender lead vocal", "heartfelt, devoted", "68-78", vocal=True),
    StyleSpec("Harp Solo", "concert harp solo", "ethereal, ceremonial", "60-70"),
    StyleSpec("String Quartet Romantic", "violin + viola + cello quartet", "lush, classic", "66-76"),
    StyleSpec("Pop Ballad Recessional", "piano + strings + soaring lead vocal + light drums", "triumphant, joyful", "82-92", vocal=True),
    StyleSpec("Acoustic Piano Solo", "solo grand piano", "reflective, gentle", "60-72"),
    StyleSpec("Ambient Modern Classical", "piano + soft pads + reverbed strings", "spacious, peaceful", "60-68"),
    StyleSpec("Bossa Nova Ceremony", "nylon guitar + soft brushes + warm bass", "breezy, romantic", "84-96"),
    StyleSpec("Folk Strings Duo", "violin + acoustic guitar", "intimate, hand-played", "72-82"),
    StyleSpec("Brass Quintet Processional", "2 trumpets + horn + trombone + tuba", "stately, ceremonial", "76-88"),
    StyleSpec("Soft Choir Pad", "choir 'aahs' + piano + light strings", "celestial, slow", "58-68"),
]

# ---------------------------------------------------------------------------
# Duration policy per category (seconds, target)
# ---------------------------------------------------------------------------

DURATION_TARGET = {
    "PRELUDE":      (150, 210),   # 2:30–3:30 - long, sets atmosphere
    "PROCESSIONAL": (90,  150),   # 1:30–2:30 - aisle walk
    "SIGNING":      (120, 180),   # 2:00–3:00 - register signing
    "RECESSIONAL":  (90,  150),   # 1:30–2:30 - exit
}

# ---------------------------------------------------------------------------

def build_brief(date: dt.date) -> list[dict]:
    """Build the day's 15-candidate slate."""
    day_seed = int(date.strftime("%Y%m%d"))
    rng = random.Random(day_seed)
    cards: list[dict] = []

    # 2 PD classics, 3 rotating genres, 10 mainstream
    pd_picks       = rng.sample(PD_CLASSICS, k=2)
    genre_picks    = rng.sample(ROTATING_GENRES, k=3)
    mainstream_picks = rng.sample(MAINSTREAM, k=10)

    pool = pd_picks + genre_picks + mainstream_picks
    rng.shuffle(pool)  # randomise which categories get which style

    for slot, style in enumerate(pool, start=1):
        category = DAILY_CATEGORY_MIX[slot - 1]
        dur_min, dur_max = DURATION_TARGET[category]
        slug = f"cand_{date.isoformat()}_{slot:02d}"
        cards.append({
            "slug": slug,
            "category": category,
            "style": style.style,
            "instrumentation": style.instrumentation,
            "mood": style.mood,
            "bpm": style.bpm,
            "vocal": style.vocal,
            "publicDomain": style.public_domain,
            "durationTargetSecs": [dur_min, dur_max],
            "notes": style.notes,
            "proposedTitle": style.style,  # editable at review time
            "status": "pending",            # pending → intaken → approved/rejected
        })
    return cards


def render_card(card: dict, idx: int) -> str:
    """Render one Suno prompt card as Markdown."""
    duration = f"{card['durationTargetSecs'][0] // 60}:{card['durationTargetSecs'][0] % 60:02d}–{card['durationTargetSecs'][1] // 60}:{card['durationTargetSecs'][1] % 60:02d}"
    vocal_line = "Vocal: tender lead, intelligible lyrics, wedding-appropriate" if card['vocal'] else "Vocal: INSTRUMENTAL - no lyrics, no vocals"
    pd_line = "  - **Public-domain classic** (AI re-record; composition PD, we own the recording)" if card['publicDomain'] else ""
    notes_line = f"  - Notes: {card['notes']}" if card['notes'] else ""

    return f"""## {idx:02d}. {card['slug']} - {card['category']}

**Style:** {card['style']}
**Save the file as:** `{card['slug']}.mp3`

```
{card['style']}, {card['instrumentation']}, {card['mood']}, {card['bpm']} BPM.
Duration {duration}. {vocal_line}.
Wedding ceremony music. Smooth, well-mixed, professional production.
```

  - Category: **{card['category']}**
  - Target duration: {duration}
  - Instrumentation: {card['instrumentation']}
  - Mood: {card['mood']}
  - BPM: {card['bpm']}{('\n  - **Vocal track** - lyric content allowed' if card['vocal'] else '\n  - Instrumental - no vocals')}
{pd_line}
{notes_line}
"""


def render_brief(date: dt.date, cards: list[dict]) -> str:
    pd_count = sum(1 for c in cards if c['publicDomain'])
    vocal_count = sum(1 for c in cards if c['vocal'])
    head = f"""# Wedding Player Catalogue - Brief for {date.isoformat()}

15 candidates. Generate each in Suno (Pro/Premier), download the MP3, and save it into this folder with the slug filename shown (e.g. `cand_{date.isoformat()}_01.mp3`).

Composition: 4 PRELUDE + 4 PROCESSIONAL + 4 SIGNING + 3 RECESSIONAL.
This day: **{pd_count} public-domain classics, {vocal_count} vocal tracks, {15 - vocal_count} instrumental.**

When a few have landed, run:
```
scripts/catalogue-pipeline/intake.sh --date {date.isoformat()}
scripts/catalogue-pipeline/review.py  --date {date.isoformat()}
```

---
"""
    body = "\n".join(render_card(c, i + 1) for i, c in enumerate(cards))
    return head + body


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--drive", default=str(DRIVE_DEFAULT),
                   help=f"Catalogue Assets dir (default: {DRIVE_DEFAULT})")
    p.add_argument("--date", default=None,
                   help="Date for the brief (YYYY-MM-DD). Defaults to today.")
    p.add_argument("--force", action="store_true",
                   help="Overwrite an existing brief for that date.")
    args = p.parse_args()

    date = dt.date.fromisoformat(args.date) if args.date else dt.date.today()
    out_dir = Path(args.drive) / "_candidates" / date.isoformat()

    if out_dir.exists() and not args.force:
        existing_brief = out_dir / "brief.md"
        if existing_brief.exists():
            print(f"✘ Brief already exists at {existing_brief}", flush=True)
            print("  Pass --force to overwrite (drops any unprocessed status flags).")
            return

    out_dir.mkdir(parents=True, exist_ok=True)
    cards = build_brief(date)

    (out_dir / "brief.md").write_text(render_brief(date, cards))
    (out_dir / "brief.json").write_text(json.dumps({
        "date": date.isoformat(),
        "candidates": cards,
    }, indent=2) + "\n")

    print(f"✓ Wrote brief: {out_dir / 'brief.md'}")
    print(f"✓ Wrote sidecar: {out_dir / 'brief.json'}")
    print(f"  {len(cards)} candidates queued. Drop generated MP3s into:")
    print(f"  {out_dir}")


if __name__ == "__main__":
    main()
