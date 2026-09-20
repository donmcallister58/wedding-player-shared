#!/usr/bin/env bash
#
# intake.sh - normalise candidate MP3s in a day's _candidates/ folder.
#
# Walks _candidates/YYYY-MM-DD/cand_*.mp3, and for each one:
#   1. Strips Suno ID3 tags, sets artist/album_artist = "Wedding Player"
#      and title = the candidate's proposed title (from brief.json)
#   2. Measures duration + peak dBFS via ffprobe / ffmpeg
#   3. Renders a 30-second preview clip into the same folder as
#      cand_<slug>_preview.mp3
#   4. Updates brief.json with status="intaken", durationSecs, peakDb
#
# Idempotent. Skips files already marked intaken whose mtime hasn't changed.
#
# Usage:
#   scripts/catalogue-pipeline/intake.sh [--drive DIR] [--date YYYY-MM-DD]

set -euo pipefail

DRIVE_DEFAULT="$HOME/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets"
DRIVE="$DRIVE_DEFAULT"
DATE="$(date +%Y-%m-%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --drive) DRIVE="$2"; shift 2 ;;
    --date)  DATE="$2";  shift 2 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

DAY_DIR="$DRIVE/_candidates/$DATE"
BRIEF="$DAY_DIR/brief.json"
[[ -f "$BRIEF" ]] || { echo "✘ No brief at $BRIEF - run brief.py first" >&2; exit 1; }

command -v ffmpeg  >/dev/null || { echo "✘ ffmpeg not on PATH" >&2; exit 1; }
command -v ffprobe >/dev/null || { echo "✘ ffprobe not on PATH" >&2; exit 1; }
command -v jq      >/dev/null || { echo "✘ jq not on PATH" >&2; exit 1; }

echo "✓ Day: $DATE"
echo "✓ Folder: $DAY_DIR"

shopt -s nullglob
CANDIDATES=("$DAY_DIR"/cand_*.mp3)
# Filter out preview files (they end in _preview.mp3).
NEW_CANDIDATES=()
for f in "${CANDIDATES[@]}"; do
  case "$f" in
    *_preview.mp3) ;;
    *) NEW_CANDIDATES+=("$f") ;;
  esac
done

if [[ ${#NEW_CANDIDATES[@]} -eq 0 ]]; then
  echo "  (no candidate MP3s found in $DAY_DIR)"
  exit 0
fi

INTAKEN=0
SKIPPED=0
TMP_BRIEF="$(mktemp)"
cp "$BRIEF" "$TMP_BRIEF"

for src in "${NEW_CANDIDATES[@]}"; do
  base="$(basename "$src" .mp3)"

  # Find this candidate's index in brief.json.
  idx=$(jq -r --arg slug "$base" '.candidates | map(.slug == $slug) | index(true) // -1' "$TMP_BRIEF")
  if [[ "$idx" == "-1" || -z "$idx" ]]; then
    echo "  ⚠ $base: not in brief.json - skipping"
    continue
  fi

  status=$(jq -r --argjson i "$idx" '.candidates[$i].status' "$TMP_BRIEF")
  preview="$DAY_DIR/${base}_preview.mp3"

  # Skip if already intaken (or further along) AND the preview exists.
  if [[ "$status" != "pending" && -f "$preview" ]]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  title=$(jq -r --argjson i "$idx" '.candidates[$i].proposedTitle' "$TMP_BRIEF")
  category=$(jq -r --argjson i "$idx" '.candidates[$i].category' "$TMP_BRIEF")

  # 1. Strip + canonicalise tags.
  tmp="${src}.tag.tmp.mp3"
  ffmpeg -y -hide_banner -loglevel error -i "$src" \
    -c copy -map_metadata -1 \
    -metadata title="$title" \
    -metadata artist="Wedding Player" \
    -metadata album_artist="Wedding Player" \
    "$tmp" && mv "$tmp" "$src"

  # 1b. Declick leading edge. Some sources (notably Mozart AI) emit a spurious
  #     click a few tens of ms into an otherwise-silent lead-in, before the music
  #     actually enters. Only tracks that start hot are touched: for those we mute
  #     the (inaudible, sub -25 dB) lead-in up to just before the musical onset
  #     and fade 20 ms into it - removing the click while leaving the music
  #     byte-for-byte intact in level. Clean-start tracks (e.g. most Suno takes)
  #     never trip the probe and are left untouched (no recompression). Fixes the
  #     shipping master, not just the preview.
  head_peak=$(ffmpeg -hide_banner -nostats -i "$src" -t 0.06 -af "volumedetect" -vn -f null - 2>&1 \
              | awk -F': ' '/max_volume/ {gsub(/ dB/, "", $2); print $2}')
  [[ -z "$head_peak" ]] && head_peak="-99"
  if awk -v p="$head_peak" 'BEGIN{exit !(p > -30)}'; then
    # Musical onset = end of the leading near-silence. -25 dB threshold keeps a
    # quiet click (which sits below it) inside the "silence" we mute.
    onset=$(ffmpeg -hide_banner -nostats -i "$src" -af "silencedetect=noise=-25dB:d=0.1" -f null - 2>&1 \
            | awk -F': ' '/silence_end/{print $2; exit}' | awk '{print $1}')
    [[ -z "$onset" ]] && onset=0
    # Mute up to 20 ms before onset, capped at 0.33 s so a genuine long quiet
    # intro is never cut; then a 20 ms fade into the music.
    mute=$(awk -v o="$onset" 'BEGIN{m=o-0.02; if(m>0.33)m=0.33; if(m<0)m=0; printf "%.3f", m}')
    if awk -v m="$mute" 'BEGIN{exit !(m > 0.001)}'; then
      filt="volume=0:enable='lt(t,$mute)',afade=t=in:st=$mute:d=0.02"
    else
      filt="afade=t=in:st=0:d=0.02"
    fi
    dc="${src}.declick.tmp.mp3"
    ffmpeg -y -hide_banner -loglevel error -i "$src" \
      -af "$filt" -b:a 320k -map_metadata 0 \
      "$dc" && mv "$dc" "$src"
    echo "    ↳ declick: ${head_peak}dB leading onset, muted lead to ${mute}s + 20ms fade"
  fi

  # 2. Measure duration + peak dBFS.
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$src")
  dur_int=$(printf '%.0f' "$dur")
  peak=$(ffmpeg -hide_banner -nostats -i "$src" -af "volumedetect" -vn -f null - 2>&1 \
          | awk -F': ' '/max_volume/ {gsub(/ dB/, "", $2); print $2}')
  [[ -z "$peak" ]] && peak="0.0"

  # 3. Generate 30s preview with category-aware start + fades.
  case "$(echo "$category" | tr '[:upper:]' '[:lower:]')" in
    prelude|signing) offset=20 ;;
    processional|recessional) offset=10 ;;
    *) offset=15 ;;
  esac
  # If the track is shorter than offset+30, start at 0.
  if (( dur_int < offset + 30 )); then offset=0; fi

  ffmpeg -y -hide_banner -loglevel error \
    -ss "$offset" -t 30 -i "$src" \
    -af "afade=t=in:st=0:d=0.4,afade=t=out:st=29.5:d=0.5" \
    -b:a 128k \
    "$preview"

  # 4. Update brief.json.
  jq --argjson i "$idx" --argjson dur "$dur_int" --arg peak "$peak" \
    '.candidates[$i].status = "intaken"
     | .candidates[$i].durationSecs = $dur
     | .candidates[$i].peakDb = ($peak | tonumber)
     | .candidates[$i].intakenAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
    "$TMP_BRIEF" > "${TMP_BRIEF}.next" && mv "${TMP_BRIEF}.next" "$TMP_BRIEF"

  echo "  ✓ $base: ${dur_int}s, peak ${peak} dBFS, preview generated"
  INTAKEN=$((INTAKEN + 1))
done

mv "$TMP_BRIEF" "$BRIEF"
echo
echo "Intake: $INTAKEN new, $SKIPPED already-intaken"
echo "Next: scripts/catalogue-pipeline/review.py --date $DATE"
