#!/usr/bin/env bash
#
# pipeline.sh - run the full post-Suno pipeline in one shot.
#
# After dropping the day's Suno-generated MP3s into _candidates/<date>/,
# run this to:
#   1. intake.sh             -> normalise tags, preview, measurements
#   2. review.py             -> interactive approval gate
#   3. generate-previews.sh  -> final 15s previews + sourceHash bump
#   4. sync-to-cdn.sh        -> upload to R2 (skipped on --no-upload)
#   5. sync-shared.sh        -> mirror into submodule (no commit; --commit to enable)
#
# Steps 1, 3, 4 are non-interactive. Step 2 is interactive by design
# (you decide what ships). Step 5 is gated behind --commit.
#
# Usage:
#   scripts/catalogue-pipeline/pipeline.sh [--date YYYY-MM-DD] [--no-upload] [--commit]
#
#   --date YYYY-MM-DD  Day folder (default: today)
#   --no-upload        Skip the CDN sync step (still does everything else)
#   --commit           After mirror, commit + bump VERSION + tag the submodule
#                      (still does NOT push; you publish manually)

set -euo pipefail

DATE="$(date +%Y-%m-%d)"
DO_UPLOAD=1
DO_COMMIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)      DATE="$2"; shift 2 ;;
    --no-upload) DO_UPLOAD=0; shift ;;
    --commit)    DO_COMMIT=1; shift ;;
    -h|--help)   sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRIVE="$HOME/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets"

banner() { echo; echo "▸ $1"; echo "────────────────────────────────────────────────────────────────"; }

banner "1/5  intake ($DATE)"
"$SCRIPT_DIR/intake.sh" --date "$DATE"

banner "2/5  review ($DATE)"
"$SCRIPT_DIR/review.py" --date "$DATE"

# Check if review.py actually approved anything; bail early if not.
APPROVED=$(jq '[.candidates[] | select(.status == "approved" and (.assignedId // "") != "" and (.publishedAt // "") == "")] | length' \
  "$DRIVE/_candidates/$DATE/brief.json" 2>/dev/null || echo 0)

if [[ "$APPROVED" -eq 0 ]]; then
  echo
  echo "No new approvals to publish. Pipeline ends here."
  exit 0
fi

banner "3/5  generate-previews ($APPROVED new tracks)"
# generate-previews.sh has a final y/N confirm; auto-yes since the human
# decision already happened in review.py.
echo "y" | "$SCRIPTS_ROOT/generate-previews.sh" --source "$DRIVE/tracks"

if [[ $DO_UPLOAD -eq 1 ]]; then
  banner "4/5  sync-to-cdn"
  "$SCRIPTS_ROOT/sync-to-cdn.sh"
else
  banner "4/5  sync-to-cdn  (skipped, --no-upload)"
fi

banner "5/5  sync-shared (submodule mirror)"
if [[ $DO_COMMIT -eq 1 ]]; then
  # sync-shared.sh has interactive y/N prompts; auto-yes both since the
  # pipeline orchestrator is the explicit opt-in for committing.
  printf "y\ny\n" | "$SCRIPT_DIR/sync-shared.sh"
else
  # No-commit path: still mirror the file, but skip commit/tag.
  printf "y\n" | "$SCRIPT_DIR/sync-shared.sh" --no-commit
fi

# Mark approvals as published so the next pipeline run won't reprocess them.
TMP=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.candidates |= map(if .status == "approved" and (.publishedAt // "") == "" then .publishedAt = $now else . end)' \
  "$DRIVE/_candidates/$DATE/brief.json" > "$TMP" && mv "$TMP" "$DRIVE/_candidates/$DATE/brief.json"

echo
echo "✓ Pipeline complete. $APPROVED track(s) published to the CDN."
if [[ $DO_COMMIT -eq 1 ]]; then
  echo "  Submodule committed + tagged (NOT pushed). To publish the bundled"
  echo "  fallback catalogue to the iOS/Android repos:"
  echo "    cd '$SCRIPTS_ROOT/..' && git push && git push --tags"
fi
