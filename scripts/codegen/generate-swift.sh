#!/usr/bin/env bash
# generate-swift.sh — produce SharedContent.generated.swift from defaults.json + en.json
#
# Usage:  ./generate-swift.sh <output-dir>
#
# Reads:  ../content/defaults.json, ../localisation/en.json (relative to this script)
# Writes: <output-dir>/SharedContent.generated.swift
#
# Idempotent. Safe to run on every iOS build.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <output-dir>" >&2
  exit 1
fi

OUT_DIR="$1"
mkdir -p "$OUT_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULTS="$REPO_ROOT/content/defaults.json"
STRINGS="$REPO_ROOT/localisation/en.json"
VERSION="$(cat "$REPO_ROOT/VERSION")"
OUT_FILE="$OUT_DIR/SharedContent.generated.swift"

[ -f "$DEFAULTS" ] || { echo "Missing: $DEFAULTS" >&2; exit 1; }
[ -f "$STRINGS"  ] || { echo "Missing: $STRINGS"  >&2; exit 1; }

# --- Header ---
cat > "$OUT_FILE" <<EOF
// GENERATED — DO NOT EDIT.
// Regenerated from wedding-player-shared@v$VERSION on each build.
// Source: content/defaults.json + localisation/en.json

import Foundation

enum SharedContent {

    // MARK: - Static models

    struct Segment {
        let key: String
        let displayKey: String
    }

    struct Colour {
        let key: String
        let displayKey: String
        let lightHex: String
        let darkHex: String
        let tabLightHex: String
        let tabDarkHex: String
    }

    struct MomentDefinition {
        let key: String
        let nameKey: String
        let shortNameKey: String
        let colourKey: String
        let segment: String
        let autoAdvanceToNext: Bool
        let sortOrder: Int
    }

    struct Playback {
        let fadeDurationSecs: Double
        let crossfadeSecs: Double
        let autoAdvance: Bool
    }

    // MARK: - Defaults

    enum Defaults {
        static let schemaVersion: Int = $(jq -r '.schemaVersion' "$DEFAULTS")
        static let cdnBaseURL: URL = URL(string: $(jq -r '.cdnBaseURL | @json' "$DEFAULTS"))!
        static let fullAccessProductId: String = $(jq -r '.iap.fullAccessProductId | @json' "$DEFAULTS")
        static let playback = Playback(
            fadeDurationSecs: $(jq -r '.playback.fadeDurationSecs' "$DEFAULTS"),
            crossfadeSecs: $(jq -r '.playback.crossfadeSecs' "$DEFAULTS"),
            autoAdvance: $(jq -r '.playback.autoAdvance' "$DEFAULTS")
        )
EOF

# --- Segments ---
{
  echo
  echo "        static let segments: [Segment] = ["
  jq -r '.segments[] | "            Segment(key: \(.key | @json), displayKey: \(.displayKey | @json)),"' "$DEFAULTS"
  echo "        ]"
} >> "$OUT_FILE"

# --- Colours (with optional Android override fields ignored on iOS) ---
{
  echo
  echo "        static let colours: [Colour] = ["
  jq -r '.colours[] | "            Colour(key: \(.key|@json), displayKey: \(.displayKey|@json), lightHex: \(.lightHex|@json), darkHex: \(.darkHex|@json), tabLightHex: \(.tabLightHex|@json), tabDarkHex: \(.tabDarkHex|@json)),"' "$DEFAULTS"
  echo "        ]"
} >> "$OUT_FILE"

# --- Colour auto-sequence ---
{
  echo
  echo "        static let colourAutoSequence: [String] = ["
  jq -r '.colourAutoSequence[] | "            \(.|@json),"' "$DEFAULTS"
  echo "        ]"
} >> "$OUT_FILE"

# --- Default moments ---
{
  echo
  echo "        static let defaultMoments: [MomentDefinition] = ["
  jq -r '.defaultMoments[] | "            MomentDefinition(key: \(.key|@json), nameKey: \(.nameKey|@json), shortNameKey: \(.shortNameKey|@json), colourKey: \(.colourKey|@json), segment: \(.segment|@json), autoAdvanceToNext: \(.autoAdvanceToNext|tostring), sortOrder: \(.sortOrder)),"' "$DEFAULTS"
  echo "        ]"
} >> "$OUT_FILE"

# --- Demo moments ---
{
  echo
  echo "        static let demoMoments: [MomentDefinition] = ["
  jq -r '.demoMoments[] | "            MomentDefinition(key: \(.key|@json), nameKey: \(.nameKey|@json), shortNameKey: \(.shortNameKey|@json), colourKey: \(.colourKey|@json), segment: \(.segment|@json), autoAdvanceToNext: \(.autoAdvanceToNext|tostring), sortOrder: \(.sortOrder)),"' "$DEFAULTS"
  echo "        ]"
  echo "    }"
} >> "$OUT_FILE"

# --- Strings (English) ---
{
  echo
  echo "    // MARK: - Strings"
  echo
  echo "    enum Strings {"
  echo "        static func en(_ key: String) -> String { enTable[key] ?? key }"
  echo
  echo "        static let enTable: [String: String] = ["
  jq -r 'to_entries[] | select(.key | startswith("_") | not) | "            \(.key|@json): \(.value|@json),"' "$STRINGS"
  echo "        ]"
  echo "    }"
} >> "$OUT_FILE"

# --- Closing + helper ---
cat >> "$OUT_FILE" <<'EOF'
}

extension String {
    static func shared(_ key: String) -> String { SharedContent.Strings.en(key) }
}
EOF

echo "Generated: $OUT_FILE ($(wc -l < "$OUT_FILE" | tr -d ' ') lines)"
