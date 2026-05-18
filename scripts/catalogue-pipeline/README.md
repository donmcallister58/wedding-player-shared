---
created: 2026-05-17T19:55
modified: 2026-05-17T19:55
author: Don McAllister
tags: [process, weddingplayer, catalogue, pipeline]
---

# Catalogue Pipeline

Scripts that grow the Wedding Player catalogue at ~15 candidates per day via Suno, with a manual approval gate before anything ships.

## Layout

```
scripts/
├── catalogue-pipeline/
│   ├── brief.py          ← daily 15-prompt generator
│   ├── intake.sh         ← candidate normaliser (tags, peak, preview)
│   ├── review.py         ← TUI approval gate
│   ├── sync-shared.sh    ← mirror Drive catalogue → submodule + tag
│   └── README.md         ← this file
├── generate-previews.sh  ← (existing) final-quality previews + hashes
└── sync-to-cdn.sh        ← (existing, now wired) upload to R2
```

Working folder for each day:

```
~/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/
  Wedding Player Catalogue Assets/
    tracks/        ← masters (canonical), wp_NNN.mp3 + catalogue.json
    previews/      ← 15-second audition clips
    _candidates/
      YYYY-MM-DD/
        brief.md           ← Suno prompts (human-readable)
        brief.json         ← machine-readable, status per candidate
        cand_<date>_NN.mp3 ← MP3 you generate in Suno, dropped here
        cand_<date>_NN_preview.mp3 ← made by intake.sh
    .uploaded.json ← sidecar of last-uploaded hashes (do not edit)
```

## Daily flow

### 1. Morning: brief

```
Shared/scripts/catalogue-pipeline/brief.py
```

Writes `_candidates/<today>/brief.md` with 15 Suno-ready prompt cards
(4 PRELUDE / 4 PROCESSIONAL / 4 SIGNING / 3 RECESSIONAL; 2 of them are
PD classics, 3 rotate through under-represented genres, 10 are mainstream
wedding styles). Each card pre-allocates a slug like `cand_2026-05-17_07`.

### 2. Generate in Suno

For each prompt card, run the prompt in Suno (Pro/Premier), download the
chosen take, and save the file as `<slug>.mp3` into the day's folder.

Skipping cards is fine. The pipeline only acts on files that land.

### 3. Intake

```
Shared/scripts/catalogue-pipeline/intake.sh --date 2026-05-17
```

For every new `cand_<date>_NN.mp3` in the folder:
- Strips Suno tags, sets canonical title/artist
- Measures duration + peak dBFS
- Renders a 15-second preview clip alongside the master
- Updates `brief.json`: status `pending → intaken` with measurements

Idempotent - already-intaken candidates are skipped.

### 4. Review

```
Shared/scripts/catalogue-pipeline/review.py --date 2026-05-17
```

Walks each intaken candidate, plays the preview, shows metadata. Hotkeys:
`a` approve · `r` reject · `e` edit (title/style/category) · `s` skip ·
`p` play again · `q` quit.

On approve:
- Allocates the next free `wp_NNN` (max + 1 from `catalogue.json`)
- Copies the master into `tracks/wp_NNN.mp3`
- Appends the row to `catalogue.json`
- Deletes the candidate master (preview stays for audit)

On reject: file stays in `_candidates/`, status flagged so re-runs skip it.

State is written after every approval, so a crash mid-session loses
nothing.

### 5. Finalise previews + tags

After any approvals, run the existing top-level preview generator. It
fills in `sourceHash` and `previewVersion` for the new rows and rebuilds
their previews at the same quality bar as the rest of the catalogue:

```
Shared/scripts/generate-previews.sh \
  --source "$HOME/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets/tracks"
```

### 6. Upload to CDN

```
Shared/scripts/sync-to-cdn.sh             # uploads only changed/new tracks
Shared/scripts/sync-to-cdn.sh --dry-run   # preview first if unsure
```

Uses the `weddingplayer-music` R2 bucket (`music/` key prefix). The
sidecar `_candidates/../.uploaded.json` (kept beside the Drive folder,
not the per-day subfolder - see `--source`) tracks which tracks have
already been uploaded so re-runs are cheap.

Verify:
```
curl -sI https://cdn.weddingplayer.app/music/catalogue.json | head -3
curl -sI https://cdn.weddingplayer.app/music/wp_NNN.mp3   | head -3
```

### 7. Mirror into submodule + tag

```
Shared/scripts/catalogue-pipeline/sync-shared.sh
```

Copies the Drive `catalogue.json` into `Shared/catalogue/catalogue.json`,
bumps the patch `VERSION`, commits, tags. **Does not push** - you decide
when to publish:

```
cd Shared
git push
git push --tags
```

Then bump the submodule pin in the iOS and Android repos to the new tag.

## Composition policy

`brief.py` deterministically produces the same brief for the same date
(seeded by `YYYYMMDD`), so re-running for a past date reproduces what
went out. The three pools live at the top of `brief.py`:

- `PD_CLASSICS` - 8 entries; 2 are picked per day
- `ROTATING_GENRES` - 11 entries; 3 picked per day
- `MAINSTREAM` - 14 entries; 10 picked per day

Adjust the lists to shift the catalogue's centre of gravity. The
duration targets per category live in `DURATION_TARGET`.

## Going daily

When you're ready for the pipeline to run unattended each morning, add a
LaunchAgent that runs `brief.py` at 07:00. Until then, run it on demand.

## Safety / idempotence summary

- `brief.py` overwrites only with `--force`
- `intake.sh` skips already-intaken candidates
- `review.py` writes state after every approval
- `generate-previews.sh` skips tracks whose `sourceHash` hasn't changed
- `sync-to-cdn.sh` skips tracks recorded in `.uploaded.json` (unless `--force`)
- `sync-shared.sh` no-ops when Drive + submodule are identical
