#!/usr/bin/env bash
#
# sync-shared.sh - mirror the Google Drive catalogue.json into the
# wedding-player-shared submodule's catalogue/catalogue.json, then offer
# to commit + bump VERSION + tag.
#
# The submodule's catalogue.json is what gets bundled into the iOS/Android
# app at build time as the offline fallback. The CDN catalogue.json is the
# live one fetched at runtime. After approving new tracks via review.py
# and pushing them to the CDN, run this to land them in the next build.
#
# Usage:
#   scripts/catalogue-pipeline/sync-shared.sh [--drive DIR] [--no-commit]

set -euo pipefail

DRIVE_DEFAULT="$HOME/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets"
DRIVE="$DRIVE_DEFAULT"
DO_COMMIT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --drive)     DRIVE="$2"; shift 2 ;;
    --no-commit) DO_COMMIT=0; shift ;;
    -h|--help)   sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"   # …/Shared
DRIVE_MANIFEST="$DRIVE/tracks/catalogue.json"
SUBMODULE_MANIFEST="$SUBMODULE_ROOT/catalogue/catalogue.json"
VERSION_FILE="$SUBMODULE_ROOT/VERSION"

[[ -f "$DRIVE_MANIFEST" ]]     || { echo "✘ Missing $DRIVE_MANIFEST" >&2; exit 1; }
[[ -f "$SUBMODULE_MANIFEST" ]] || { echo "✘ Missing $SUBMODULE_MANIFEST" >&2; exit 1; }

if diff -q "$DRIVE_MANIFEST" "$SUBMODULE_MANIFEST" >/dev/null; then
  echo "✓ Already in sync - nothing to do."
  exit 0
fi

# Count change
DRIVE_COUNT=$(jq 'length' "$DRIVE_MANIFEST")
SUB_COUNT=$(jq 'length' "$SUBMODULE_MANIFEST")
DELTA=$((DRIVE_COUNT - SUB_COUNT))

# New ids (rough - assumes only-add growth; rejects edits-without-add)
NEW_IDS=$(jq -r 'map(.id)' "$DRIVE_MANIFEST" | jq -r --slurpfile sub <(jq 'map(.id)' "$SUBMODULE_MANIFEST") \
  '. - $sub[0] | join(", ")' 2>/dev/null || echo "(unable to compute)")

echo "Drive catalogue:      $DRIVE_COUNT tracks"
echo "Submodule catalogue:  $SUB_COUNT tracks  (Δ +$DELTA)"
echo "New ids:              $NEW_IDS"
echo

read -r -p "Mirror Drive → submodule? [y/N] " CONFIRM
[[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || { echo "Aborted."; exit 1; }

cp "$DRIVE_MANIFEST" "$SUBMODULE_MANIFEST"
echo "✓ Copied $DRIVE_MANIFEST → $SUBMODULE_MANIFEST"

if [[ $DO_COMMIT -eq 0 ]]; then
  echo "✓ --no-commit set; submodule left dirty. Commit/tag manually when ready."
  exit 0
fi

# Compute the next free patch tag from the actual tag list, not VERSION.
# VERSION drifts (the submodule carries strings + help content + codegen,
# all of which get their own tags between catalogue commits). Tags are
# the source of truth.
cd "$SUBMODULE_ROOT"
git fetch --tags --quiet 2>/dev/null || true
LATEST_TAG="$(git tag --sort=-v:refname | head -1)"
if [[ -z "$LATEST_TAG" ]]; then
  echo "✘ No existing tags - aborting (refusing to seed v1.0.0 from this script)" >&2
  exit 1
fi
IFS='.' read -r MAJ MIN PAT <<<"${LATEST_TAG#v}"
PAT=$((PAT + 1))
NEW_VER="$MAJ.$MIN.$PAT"
CURRENT="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || echo 'unknown')"

echo
echo "Latest tag:  $LATEST_TAG"
echo "VERSION file: $CURRENT  $([ "$CURRENT" != "${LATEST_TAG#v}" ] && echo '(stale; will be refreshed)')"
echo "Proposed:    tag v$NEW_VER  +  VERSION → $NEW_VER"
read -r -p "Commit + tag? [y/N] " CONFIRM2
[[ "$CONFIRM2" == "y" || "$CONFIRM2" == "Y" ]] || { echo "Skipped commit. catalogue.json staged, VERSION unchanged."; exit 0; }

echo "$NEW_VER" > "$VERSION_FILE"
git add catalogue/catalogue.json VERSION
git commit -m "Catalogue: +$DELTA tracks ($NEW_IDS) - v$NEW_VER"
git tag "v$NEW_VER"

echo
echo "✓ Committed and tagged v$NEW_VER (not pushed)."
echo "  To publish: cd '$SUBMODULE_ROOT' && git push && git push --tags"
echo "  Then bump the submodule pin in the iOS + Android repos to v$NEW_VER."
