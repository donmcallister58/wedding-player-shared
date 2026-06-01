#!/usr/bin/env bash
#
# generate-previews.sh
#
# Builds 30-second audition clips for every track in the Wedding Player
# catalogue, updates the manifest with sha256 source hashes + preview
# versions, and (optionally) uploads the result to the CDN.
#
# Idempotent: re-running with no source changes does nothing.
#
# Usage:
#   scripts/generate-previews.sh [--source DIR] [--upload] [--force]
#
# Defaults:
#   --source: prompts you to confirm a directory containing wp_*.mp3
#   --upload: skipped unless flag passed; always prints the upload command
#             so you can run it manually if you'd rather not wire credentials
#   --force:  regenerate every preview regardless of sourceHash. Needed when
#             the preview spec changes (e.g. clip length) without the source
#             MP3s changing, since that does not alter the hash.
#
# Requirements: ffmpeg, jq, shasum (preinstalled on macOS).

set -euo pipefail

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------

SOURCE_DIR=""
DO_UPLOAD=0
FORCE=0
PREVIEW_LEN=30
TARGET_BITRATE="128k"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE_DIR="$2"; shift 2 ;;
    --upload) DO_UPLOAD=1; shift ;;
    --force)  FORCE=1; shift ;;
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Locate source directory
# ---------------------------------------------------------------------------

if [[ -z "$SOURCE_DIR" ]]; then
  cat <<EOF
Where do the catalogue source MP3s live? (must contain wp_001.mp3 etc.)
Common locations:
  /Volumes/Crucial-2TB/Assets/WeddingPlayer/_sources/audio/catalogue
  ~/Developer/apps/web-apps/weddingplayer-site/public/music
EOF
  read -r -p "Path: " SOURCE_DIR
fi

SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "✘ Source dir not found: $SOURCE_DIR" >&2
  exit 1
fi

shopt -s nullglob
SOURCES=("$SOURCE_DIR"/wp_*.mp3)
if [[ ${#SOURCES[@]} -eq 0 ]]; then
  echo "✘ No wp_*.mp3 files in $SOURCE_DIR" >&2
  exit 1
fi
echo "✓ Found ${#SOURCES[@]} source MP3s in $SOURCE_DIR"

# ---------------------------------------------------------------------------
# Locate manifest
# ---------------------------------------------------------------------------

# Look for catalogue.json next to the sources, otherwise prompt.
MANIFEST=""
for candidate in \
  "$SOURCE_DIR/catalogue.json" \
  "$SOURCE_DIR/../catalogue.json" \
  "$(cd "$(dirname "$0")/.." && pwd)/scripts/catalogue.json"
do
  if [[ -f "$candidate" ]]; then MANIFEST="$candidate"; break; fi
done

if [[ -z "$MANIFEST" ]]; then
  read -r -p "Path to existing catalogue.json (or 'new' to seed from sources): " MANIFEST
  MANIFEST="${MANIFEST/#\~/$HOME}"
  if [[ "$MANIFEST" == "new" ]]; then
    MANIFEST="$SOURCE_DIR/catalogue.json"
    echo "[]" > "$MANIFEST"
    echo "Seeded empty manifest at $MANIFEST"
    echo "✘ Refusing to continue with empty manifest — populate track metadata first." >&2
    exit 1
  fi
fi
echo "✓ Manifest: $MANIFEST"

# ---------------------------------------------------------------------------
# Output dir
#
# If the manifest sits inside a `tracks/` folder (the canonical Google
# Drive layout: `Wedding Player Catalogue Assets/{tracks,previews}/`),
# write previews to the sibling `previews/` directory so the two stay
# co-located but separate. Otherwise put them inside the manifest folder.
# ---------------------------------------------------------------------------

MANIFEST_DIR="$(dirname "$MANIFEST")"
if [[ "$(basename "$MANIFEST_DIR")" == "tracks" ]]; then
  PREVIEW_DIR="$(dirname "$MANIFEST_DIR")/previews"
else
  PREVIEW_DIR="$MANIFEST_DIR/previews"
fi
mkdir -p "$PREVIEW_DIR"
echo "✓ Output dir: $PREVIEW_DIR"

# ---------------------------------------------------------------------------
# Per-category start offset
# ---------------------------------------------------------------------------

offset_for_category() {
  # Manifest stores categories as either "Prelude" or "PRELUDE"; the iOS
  # decoder is case-insensitive so we match the same way here.
  local cat
  cat=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$cat" in
    prelude|signing) echo 20 ;;
    processional|recessional) echo 10 ;;
    *) echo 15 ;;
  esac
}

# ---------------------------------------------------------------------------
# Tag normalisation
#
# Every source MP3 is forced into a canonical tag set:
#   title        = manifest title (e.g. "Classical Strings")
#   artist       = "Wedding Player"
#   album_artist = "Wedding Player"
#   (everything else stripped — Suno comments, year, genre, etc.)
#
# Done before hashing so a re-tag always invalidates sourceHash and
# triggers a preview regen. New tracks get the same treatment on first
# run — drop a fresh MP3 in tracks/, add the manifest entry, run the
# script, and tags come out canonical.
# ---------------------------------------------------------------------------

normalise_tags() {
  local src="$1"
  local title="$2"
  local current_artist current_title current_comment
  current_artist=$(ffprobe -v error -show_entries format_tags=artist -of csv=p=0 "$src" 2>/dev/null)
  current_title=$(ffprobe -v error -show_entries format_tags=title -of csv=p=0 "$src" 2>/dev/null)
  current_comment=$(ffprobe -v error -show_entries format_tags=comment -of csv=p=0 "$src" 2>/dev/null)

  # Skip the ffmpeg rewrite if everything is already canonical AND there
  # are no extra tags to strip. Cheap: avoids re-writing 36 files on every run.
  if [[ "$current_artist" == "Wedding Player" \
     && "$current_title"  == "$title" \
     && -z "$current_comment" ]]; then
    return 0
  fi

  local tmp="${src}.tag.tmp.mp3"
  # -map_metadata -1 strips ALL existing tags, then -metadata adds back
  # exactly the three we want. -c copy = no re-encode (lossless).
  ffmpeg -y -hide_banner -loglevel error -i "$src" \
    -c copy -map_metadata -1 \
    -metadata title="$title" \
    -metadata artist="Wedding Player" \
    -metadata album_artist="Wedding Player" \
    "$tmp" && mv "$tmp" "$src"
}

# ---------------------------------------------------------------------------
# Process each track
# ---------------------------------------------------------------------------

CHANGED=0
TMP_MANIFEST="$(mktemp)"
cp "$MANIFEST" "$TMP_MANIFEST"

# Walk the manifest (single source of truth for IDs + categories).
TRACK_COUNT=$(jq 'length' "$TMP_MANIFEST")
for ((i=0; i<TRACK_COUNT; i++)); do
  ID=$(jq -r ".[$i].id" "$TMP_MANIFEST")
  FILENAME=$(jq -r ".[$i].filename" "$TMP_MANIFEST")
  CATEGORY=$(jq -r ".[$i].category" "$TMP_MANIFEST")
  TITLE=$(jq -r ".[$i].title" "$TMP_MANIFEST")
  OLD_HASH=$(jq -r ".[$i].sourceHash // empty" "$TMP_MANIFEST")
  OLD_VERSION=$(jq -r ".[$i].previewVersion // 0" "$TMP_MANIFEST")

  SRC="$SOURCE_DIR/$FILENAME"
  if [[ ! -f "$SRC" ]]; then
    echo "  ⚠ $ID: missing source $FILENAME — skipping"
    continue
  fi

  # Normalise tags BEFORE hashing — keeps the canonical title/artist
  # set in lock-step with the manifest, and makes any tag drift a
  # source-hash change that triggers preview regen.
  normalise_tags "$SRC" "$TITLE"

  NEW_HASH=$(shasum -a 256 "$SRC" | awk '{print $1}')
  PREVIEW="$PREVIEW_DIR/$FILENAME"

  if [[ $FORCE -eq 0 && "$NEW_HASH" == "$OLD_HASH" && -f "$PREVIEW" ]]; then
    continue  # unchanged, preview present
  fi

  OFFSET=$(offset_for_category "$CATEGORY")
  echo "  ↻ $ID ($CATEGORY): regenerating preview at offset ${OFFSET}s"

  # Short fade in/out so the clip never starts/ends on a click.
  ffmpeg -y -hide_banner -loglevel error \
    -ss "$OFFSET" -t "$PREVIEW_LEN" \
    -i "$SRC" \
    -af "afade=t=in:st=0:d=0.4,afade=t=out:st=$(echo "$PREVIEW_LEN - 0.5" | bc):d=0.5" \
    -b:a "$TARGET_BITRATE" \
    "$PREVIEW"

  NEW_VERSION=$((OLD_VERSION + 1))
  jq ".[$i].sourceHash = \"$NEW_HASH\" | .[$i].previewVersion = $NEW_VERSION" \
    "$TMP_MANIFEST" > "${TMP_MANIFEST}.next" && mv "${TMP_MANIFEST}.next" "$TMP_MANIFEST"
  CHANGED=$((CHANGED + 1))
done

if [[ $CHANGED -eq 0 ]]; then
  echo "✓ No changes — all previews up to date."
  rm -f "$TMP_MANIFEST"
  exit 0
fi

echo
echo "Manifest diff:"
diff -u "$MANIFEST" "$TMP_MANIFEST" || true
echo

read -r -p "Write updated manifest to $MANIFEST ? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted. Updated manifest left at $TMP_MANIFEST"
  exit 1
fi
mv "$TMP_MANIFEST" "$MANIFEST"
echo "✓ Updated $MANIFEST ($CHANGED tracks)"

# ---------------------------------------------------------------------------
# Upload guidance
# ---------------------------------------------------------------------------

cat <<EOF

Next: upload the regenerated previews + manifest to the CDN.
  • Previews:  $PREVIEW_DIR/*.mp3  →  https://cdn.weddingplayer.app/music/previews/
  • Manifest:  $MANIFEST           →  https://cdn.weddingplayer.app/music/catalogue.json

Run the same upload mechanism you use for the full catalogue MP3s
(wrangler / rsync / Cloudflare dashboard — whichever you've been using).

This script does NOT upload automatically — credentials and the upload
target aren't wired here. Pass --upload after wiring it if you want.
EOF

if [[ $DO_UPLOAD -eq 1 ]]; then
  echo
  echo "✘ --upload was requested but no upload command is configured." >&2
  echo "  Edit this script to add the appropriate wrangler / rsync call," >&2
  echo "  then re-run. Refusing to silently no-op." >&2
  exit 1
fi
