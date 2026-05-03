#!/usr/bin/env bash
# sync-to-cdn.sh — upload catalogue + previews to the Wedding Player CDN
#
# Status: PLACEHOLDER. CDN upload mechanism is currently manual.
# Wire up the actual upload command (rsync, wrangler, aws s3, gh-pages, etc.) here.
#
# Usage: ./sync-to-cdn.sh [<track-id>]
#   No arg     — sync the entire catalogue/ tree
#   With arg   — sync just one track (e.g. wp_037), its preview, and the catalogue.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cat <<'EOF' >&2
sync-to-cdn.sh is a PLACEHOLDER.

Today CDN updates are manual — see CLAUDE.md for the in-app catalogue audio (Google Drive)
section, which describes the workflow: upload tracks/wp_NNN.mp3, previews/wp_NNN.mp3,
and catalogue.json to the CDN.

To fully automate, replace this body with the actual upload command. Likely candidates:
  - Cloudflare R2 + wrangler:    wrangler r2 object put …
  - rsync over ssh:               rsync -av catalogue/ user@host:/var/www/cdn/music/
  - AWS S3:                       aws s3 sync catalogue/ s3://bucket/music/

EOF
exit 1
