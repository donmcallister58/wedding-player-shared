#!/usr/bin/env bash
#
# sync-to-cdn.sh - upload catalogue masters + previews + manifest to the
# Wedding Player CDN (Cloudflare R2 bucket `weddingplayer-music`, served
# from https://cdn.weddingplayer.app/music/).
#
# Idempotent. Tracks already on the CDN are skipped via a local
# `.uploaded.json` sidecar that records the sourceHash + previewVersion
# of the last successful upload per track. Re-run safely.
#
# After a successful catalogue.json upload it fires the weddingplayer-site
# Cloudflare Pages deploy hook (URL from a gitignored `.deploy-hook` file
# next to this script) so the public /music page rebuilds automatically.
#
# Usage:
#   scripts/sync-to-cdn.sh [--source DIR] [--dry-run] [--force] [--only wp_NNN]
#
#   --source DIR   Catalogue assets dir (defaults to the Google Drive path
#                  below). Must contain `tracks/catalogue.json`,
#                  `tracks/wp_*.mp3`, and `previews/wp_*.mp3`.
#   --dry-run      Print what would be uploaded; perform no writes.
#   --force        Ignore the sidecar and upload everything.
#   --only wp_NNN  Restrict to a single track id (still re-uploads
#                  catalogue.json at the end so the manifest matches).
#
# Requirements: wrangler, jq.

set -euo pipefail

BUCKET="weddingplayer-music"
KEY_PREFIX="music"
DEFAULT_SOURCE="$HOME/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_DIR=""
DRY_RUN=0
FORCE=0
ONLY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)  SOURCE_DIR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force)   FORCE=1; shift ;;
    --only)    ONLY="$2"; shift 2 ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$SOURCE_DIR" ]] && SOURCE_DIR="$DEFAULT_SOURCE"
SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"

MANIFEST="$SOURCE_DIR/tracks/catalogue.json"
TRACKS_DIR="$SOURCE_DIR/tracks"
PREVIEWS_DIR="$SOURCE_DIR/previews"
SIDECAR="$SOURCE_DIR/.uploaded.json"

[[ -f "$MANIFEST" ]]    || { echo "✘ Missing manifest: $MANIFEST" >&2; exit 1; }
[[ -d "$TRACKS_DIR" ]]  || { echo "✘ Missing tracks dir: $TRACKS_DIR" >&2; exit 1; }
[[ -d "$PREVIEWS_DIR" ]]|| { echo "✘ Missing previews dir: $PREVIEWS_DIR" >&2; exit 1; }

command -v wrangler >/dev/null || { echo "✘ wrangler not on PATH" >&2; exit 1; }
command -v jq       >/dev/null || { echo "✘ jq not on PATH" >&2; exit 1; }

[[ -f "$SIDECAR" ]] || echo '{}' > "$SIDECAR"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "🔎 DRY RUN - no uploads will be performed"
fi
echo "✓ Source: $SOURCE_DIR"
echo "✓ Bucket: r2://$BUCKET/$KEY_PREFIX/"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

put() {
  # put <local-path> <remote-key> <content-type>
  local local_path="$1" remote_key="$2" content_type="$3"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  ⤴ would upload $local_path  →  $remote_key  ($content_type)"
    return 0
  fi
  wrangler r2 object put "$BUCKET/$remote_key" \
    --file "$local_path" \
    --content-type "$content_type" \
    --remote >/dev/null
  echo "  ⤴ uploaded $remote_key"
}

# Mark a track as uploaded in the sidecar (no-op on dry-run).
record_uploaded() {
  local id="$1" src_hash="$2" preview_ver="$3"
  [[ $DRY_RUN -eq 1 ]] && return 0
  jq --arg id "$id" --arg h "$src_hash" --arg v "$preview_ver" \
    '.[$id] = {sourceHash: $h, previewVersion: ($v|tonumber)}' \
    "$SIDECAR" > "${SIDECAR}.next" && mv "${SIDECAR}.next" "$SIDECAR"
}

# Fire the Cloudflare Pages deploy hook so the public /music page rebuilds
# against the freshly-uploaded catalogue. The hook URL is a secret: it lives
# in a gitignored `.deploy-hook` file next to this script. Missing or empty
# file = skip with a warning (the CDN upload itself still succeeded).
trigger_site_rebuild() {
  local hook_file="$SCRIPT_DIR/.deploy-hook"
  if [[ ! -f "$hook_file" ]]; then
    echo "  ⚠ no .deploy-hook file - skipping site rebuild trigger"
    echo "    create $hook_file with the Cloudflare Pages deploy hook URL"
    return 0
  fi
  local hook_url
  hook_url="$(tr -d '[:space:]' < "$hook_file")"
  if [[ -z "$hook_url" ]]; then
    echo "  ⚠ .deploy-hook is empty - skipping site rebuild trigger"
    return 0
  fi
  if curl -fsS -X POST "$hook_url" >/dev/null; then
    echo "  ⤴ triggered weddingplayer-site rebuild"
  else
    echo "  ⚠ deploy hook POST failed - catalogue uploaded OK, rebuild the site manually" >&2
  fi
}

# ---------------------------------------------------------------------------
# Walk the manifest
# ---------------------------------------------------------------------------

TRACK_COUNT=$(jq 'length' "$MANIFEST")
UPLOADED=0
SKIPPED=0

for ((i=0; i<TRACK_COUNT; i++)); do
  ID=$(jq -r       ".[$i].id"             "$MANIFEST")
  FILENAME=$(jq -r ".[$i].filename"       "$MANIFEST")
  NEW_HASH=$(jq -r ".[$i].sourceHash // empty" "$MANIFEST")
  NEW_VERSION=$(jq -r ".[$i].previewVersion // 0" "$MANIFEST")

  if [[ -n "$ONLY" && "$ID" != "$ONLY" ]]; then continue; fi

  if [[ -z "$NEW_HASH" ]]; then
    echo "  ⚠ $ID: no sourceHash in manifest - run generate-previews.sh first"
    continue
  fi

  OLD_HASH=$(jq -r --arg id "$ID" '.[$id].sourceHash // empty' "$SIDECAR")
  OLD_VERSION=$(jq -r --arg id "$ID" '.[$id].previewVersion // 0' "$SIDECAR")

  TRACK_SRC="$TRACKS_DIR/$FILENAME"
  PREVIEW_SRC="$PREVIEWS_DIR/$FILENAME"

  NEEDS_TRACK=0
  NEEDS_PREVIEW=0
  if [[ $FORCE -eq 1 || "$NEW_HASH" != "$OLD_HASH" ]];       then NEEDS_TRACK=1;   fi
  if [[ $FORCE -eq 1 || "$NEW_VERSION" != "$OLD_VERSION" ]]; then NEEDS_PREVIEW=1; fi

  if [[ $NEEDS_TRACK -eq 0 && $NEEDS_PREVIEW -eq 0 ]]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "$ID:"
  if [[ $NEEDS_TRACK -eq 1 ]]; then
    [[ -f "$TRACK_SRC" ]] || { echo "  ✘ missing $TRACK_SRC" >&2; exit 1; }
    put "$TRACK_SRC" "$KEY_PREFIX/$FILENAME" "audio/mpeg"
  fi
  if [[ $NEEDS_PREVIEW -eq 1 ]]; then
    [[ -f "$PREVIEW_SRC" ]] || { echo "  ✘ missing $PREVIEW_SRC" >&2; exit 1; }
    put "$PREVIEW_SRC" "$KEY_PREFIX/previews/$FILENAME" "audio/mpeg"
  fi
  record_uploaded "$ID" "$NEW_HASH" "$NEW_VERSION"
  UPLOADED=$((UPLOADED + 1))
done

echo
echo "Tracks: $UPLOADED uploaded, $SKIPPED skipped (already current)"

# ---------------------------------------------------------------------------
# Manifest last (so the public manifest never references missing files)
# ---------------------------------------------------------------------------

if [[ $UPLOADED -gt 0 || $FORCE -eq 1 ]]; then
  echo
  echo "catalogue.json:"
  put "$MANIFEST" "$KEY_PREFIX/catalogue.json" "application/json"
  if [[ $DRY_RUN -eq 0 ]]; then
    trigger_site_rebuild
  fi
else
  echo
  echo "catalogue.json: skipped (no track changes; manifest already matches)"
fi

if [[ $DRY_RUN -eq 0 ]]; then
  echo
  echo "✓ Done. Verify:"
  echo "  curl -sI https://cdn.weddingplayer.app/music/catalogue.json | head -3"
  if [[ -n "$ONLY" ]]; then
    echo "  curl -sI https://cdn.weddingplayer.app/music/$ONLY.mp3 | head -3"
  fi
fi
