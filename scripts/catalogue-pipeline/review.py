#!/usr/bin/env python3
"""review.py - terminal TUI to approve / reject intaken candidates.

Walks the day's intaken candidates (status="intaken"), plays each preview
via `afplay`, shows the proposed metadata, and offers:

  a   approve - allocate wp_NNN, move file to tracks/, append to catalogue.json
  r   reject - mark rejected; file stays in _candidates/ (for archive)
  e   edit - edit title / style / category before deciding
  s   skip - leave as intaken; revisit later
  q   quit

Approved tracks are appended to the Google Drive `tracks/catalogue.json`.
The next free wp_NNN is allocated by max(existing ids) + 1.

After approval, run:
  Shared/scripts/generate-previews.sh --source <drive>/tracks
  Shared/scripts/sync-to-cdn.sh
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

DRIVE_DEFAULT = Path.home() / "Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets"
CATEGORIES = ["PRELUDE", "PROCESSIONAL", "SIGNING", "RECESSIONAL"]

# Hidden artist-search aliases live in the website repo, NOT the catalogue:
# they are never uploaded to the CDN and never displayed, only used as
# invisible search keywords on the public /music page.
SITE_STYLE_REFS_DEFAULT = Path.home() / "Developer/apps/web-apps/weddingplayer-site/src/data/style-refs.json"


def next_wp_id(catalogue: list[dict]) -> str:
    """Return the next free wp_NNN id (max existing + 1, zero-padded)."""
    ids = [c["id"] for c in catalogue if re.match(r"^wp_\d+$", c["id"])]
    nums = [int(i.split("_")[1]) for i in ids]
    nxt = (max(nums) if nums else 0) + 1
    return f"wp_{nxt:03d}"


def tempo_from_bpm(bpm: str) -> str:
    """Map a BPM string ('60-66') to the coarse tempo facet used by /music."""
    m = re.search(r"\d+", bpm or "")
    if not m:
        return ""
    n = int(m.group())
    if n < 72:
        return "Slow"
    if n <= 90:
        return "Moderate"
    return "Lively"


def write_style_refs(path: Path, track_id: str, refs: list[str]) -> None:
    """Append hidden artist-search aliases for a track to style-refs.json.

    Private file: never uploaded to the CDN. The tokens are used only as
    invisible search keywords on the public /music page.
    """
    refs = [r.strip() for r in refs if r.strip()]
    if not refs:
        return
    data: dict = {}
    if path.exists():
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            data = {}
    data[track_id] = refs
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    print(f"  ✓ Wrote {len(refs)} hidden style-ref(s) for {track_id}")


def play_preview(preview_path: Path) -> None:
    """Play the preview clip via afplay (macOS). Non-blocking - user controls duration."""
    if not preview_path.exists():
        print(f"  ⚠ preview not found: {preview_path}")
        return
    try:
        subprocess.run(["afplay", str(preview_path)], check=False)
    except FileNotFoundError:
        print("  ⚠ afplay not found (macOS only). Skipping playback.")


def edit_metadata(card: dict) -> dict:
    """Prompt for new title / style / category / style-refs. Empty input keeps current."""
    print()
    new_title = input(f"  Title    [{card['proposedTitle']}]: ").strip()
    new_style = input(f"  Style    [{card['style']}]: ").strip()
    new_cat   = input(f"  Category [{card['category']}] ({'/'.join(CATEGORIES)}): ").strip().upper()
    cur_refs  = ", ".join(card.get("styleRefs", []))
    new_refs  = input(f"  Style-refs (hidden artist aliases, comma-sep) [{cur_refs}]: ").strip()
    if new_title: card["proposedTitle"] = new_title
    if new_style: card["style"] = new_style
    if new_cat:
        if new_cat not in CATEGORIES:
            print(f"  ✘ invalid category - keeping {card['category']}")
        else:
            card["category"] = new_cat
    if new_refs:
        card["styleRefs"] = [r.strip() for r in new_refs.split(",") if r.strip()]
    return card


def show_card(card: dict, day_dir: Path) -> None:
    print()
    print("=" * 64)
    print(f"  {card['slug']}  [{card.get('status', '?')}]")
    print("=" * 64)
    print(f"  Title:       {card['proposedTitle']}")
    print(f"  Style:       {card['style']}")
    print(f"  Category:    {card['category']}")
    print(f"  Genre:       {card.get('genre', '?')}")
    print(f"  Moods:       {', '.join(card.get('moods', [])) or '?'}")
    print(f"  Duration:    {card.get('durationSecs', '?')}s")
    print(f"  Peak:        {card.get('peakDb', '?')} dBFS")
    print(f"  Vocal:       {card['vocal']}")
    print(f"  Public dom:  {card['publicDomain']}")
    print(f"  Instrument:  {card['instrumentation']} ({card.get('instrFacet', '?')})")
    print(f"  Mood:        {card['mood']}, {card['bpm']} BPM")
    if card.get("styleRefs"):
        print(f"  Style-refs:  {', '.join(card['styleRefs'])}  (hidden)")
    if card.get("notes"):
        print(f"  Notes:       {card['notes']}")
    print(f"  Preview:     {day_dir / (card['slug'] + '_preview.mp3')}")


def promote_candidate(card: dict, drive: Path, day_dir: Path, catalogue: list[dict],
                      style_refs_path: Path) -> dict:
    """Move the candidate MP3 into tracks/wp_NNN.mp3 and append the catalogue row."""
    new_id = next_wp_id(catalogue)
    src = day_dir / f"{card['slug']}.mp3"
    if not src.exists():
        raise FileNotFoundError(f"Master MP3 missing: {src}")
    dest = drive / "tracks" / f"{new_id}.mp3"

    shutil.copy2(src, dest)  # keep candidate intact for audit; tracks/ now has wp_NNN
    src.unlink()              # remove the candidate master (preview stays for audit)

    row = {
        "id": new_id,
        "title": card["proposedTitle"],
        "style": card["style"],
        "category": card["category"],
        "genre": card.get("genre", ""),
        "mood": list(card.get("moods", [])),
        "instrumentation": card.get("instrFacet", ""),
        "tempo": tempo_from_bpm(card.get("bpm", "")),
        "vocal": bool(card.get("vocal", False)),
        "durationSecs": card.get("durationSecs") or 0,
        "dateAdded": dt.date.today().isoformat(),
        "filename": f"{new_id}.mp3",
        # sourceHash + previewVersion filled in by generate-previews.sh
    }
    catalogue.append(row)
    # Hidden artist-search aliases go to the private style-refs.json, never the catalogue.
    if card.get("styleRefs"):
        write_style_refs(style_refs_path, new_id, card["styleRefs"])
    return row


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--drive", default=str(DRIVE_DEFAULT))
    p.add_argument("--date", default=None,
                   help="Date folder to review (YYYY-MM-DD). Defaults to today.")
    p.add_argument("--summary", action="store_true",
                   help="Print counts for the day and exit (no interactive flow).")
    p.add_argument("--site-data", default=str(SITE_STYLE_REFS_DEFAULT),
                   help="Path to the website's style-refs.json (hidden artist search tokens).")
    args = p.parse_args()

    drive = Path(args.drive)
    style_refs_path = Path(args.site_data)
    date = dt.date.fromisoformat(args.date) if args.date else dt.date.today()
    day_dir = drive / "_candidates" / date.isoformat()
    brief_path = day_dir / "brief.json"
    catalogue_path = drive / "tracks" / "catalogue.json"

    if not brief_path.exists():
        print(f"✘ No brief.json at {brief_path}", file=sys.stderr)
        sys.exit(1)
    if not catalogue_path.exists():
        print(f"✘ No catalogue.json at {catalogue_path}", file=sys.stderr)
        sys.exit(1)

    brief = json.loads(brief_path.read_text())
    catalogue = json.loads(catalogue_path.read_text())

    cards = brief["candidates"]

    if args.summary:
        counts = {"pending": 0, "intaken": 0, "approved": 0, "rejected": 0}
        for c in cards:
            counts[c.get("status", "pending")] = counts.get(c.get("status", "pending"), 0) + 1
        print(f"Day {date.isoformat()}:")
        for k, v in counts.items():
            print(f"  {k:>9}: {v}")
        return

    intaken = [c for c in cards if c.get("status") == "intaken"]
    if not intaken:
        print(f"No intaken candidates for {date.isoformat()}. Run intake.sh first.")
        return

    print(f"✓ {len(intaken)} candidate(s) ready for review.")
    approved_ids: list[str] = []

    for card in intaken:
        show_card(card, day_dir)
        print()
        print("  (a)pprove  (r)eject  (e)dit  (s)kip  (p)lay-again  (q)uit")
        play_preview(day_dir / f"{card['slug']}_preview.mp3")

        while True:
            choice = input("  > ").strip().lower()
            if choice == "a":
                row = promote_candidate(card, drive, day_dir, catalogue, style_refs_path)
                card["status"] = "approved"
                card["assignedId"] = row["id"]
                card["approvedAt"] = dt.datetime.utcnow().isoformat(timespec="seconds") + "Z"
                approved_ids.append(row["id"])
                # Persist after each approval so a crash doesn't lose work.
                brief_path.write_text(json.dumps(brief, indent=2) + "\n")
                catalogue_path.write_text(json.dumps(catalogue, indent=2) + "\n")
                print(f"  ✓ Approved as {row['id']}")
                break
            elif choice == "r":
                card["status"] = "rejected"
                card["rejectedAt"] = dt.datetime.utcnow().isoformat(timespec="seconds") + "Z"
                brief_path.write_text(json.dumps(brief, indent=2) + "\n")
                print("  ✓ Rejected (file kept in _candidates/ for audit)")
                break
            elif choice == "e":
                edit_metadata(card)
                show_card(card, day_dir)
                # don't break - re-prompt
            elif choice == "s":
                print("  ↷ Skipped (still intaken)")
                break
            elif choice == "p":
                play_preview(day_dir / f"{card['slug']}_preview.mp3")
            elif choice == "q":
                print("Quit. Progress saved.")
                _print_summary(approved_ids)
                return
            else:
                print("  ?  a / r / e / s / p / q")

    _print_summary(approved_ids)
    if approved_ids:
        print()
        print("Next steps:")
        print(f"  Shared/scripts/generate-previews.sh --source '{drive}/tracks'")
        print(f"  Shared/scripts/sync-to-cdn.sh")
        print(f"  Shared/scripts/catalogue-pipeline/sync-shared.sh   # mirror into submodule")


def _print_summary(approved_ids: list[str]) -> None:
    print()
    print(f"Approved this session: {len(approved_ids)}")
    for i in approved_ids:
        print(f"  • {i}")


if __name__ == "__main__":
    main()
