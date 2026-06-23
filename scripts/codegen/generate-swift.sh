#!/usr/bin/env bash
# generate-swift.sh — produce SharedContent.generated.swift from defaults.json + en.json
#
# Usage:  ./generate-swift.sh <output-dir>
#
# Reads:  ../content/defaults.json, ../localisation/en.json (relative to this script)
# Writes: <output-dir>/SharedContent.generated.swift
#
# Idempotent. Safe to run on every iOS build.
#
# defaults.json is locale-indexed (.locales.<REGION>.{segments,defaultMoments,demoMoments}).
# The flat Defaults.segments/defaultMoments/demoMoments accessors emit the .defaultLocale
# template (backward-compatible). Defaults.localeTemplates exposes every region for
# locale-aware seeding of new ceremonies.

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

DEFAULT_LOCALE="$(jq -r '.defaultLocale' "$DEFAULTS")"

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

    /// A per-region wedding-structure template (phases + starter moments).
    /// \`segments\` carries the region's phase keys (GB: daytime/evening; US: ceremony/cocktail/reception).
    struct LocaleTemplate {
        let segments: [Segment]
        let defaultMoments: [MomentDefinition]
        let demoMoments: [MomentDefinition]
    }

    // MARK: - Defaults

    enum Defaults {
        static let schemaVersion: Int = $(jq -r '.schemaVersion' "$DEFAULTS")
        static let cdnBaseURL: URL = URL(string: $(jq -r '.cdnBaseURL | @json' "$DEFAULTS"))!
        static let fullAccessProductId: String = $(jq -r '.iap.fullAccessProductId | @json' "$DEFAULTS")
        static let defaultLocale: String = $(jq -r '.defaultLocale | @json' "$DEFAULTS")
        static let playback = Playback(
            fadeDurationSecs: $(jq -r '.playback.fadeDurationSecs' "$DEFAULTS"),
            crossfadeSecs: $(jq -r '.playback.crossfadeSecs' "$DEFAULTS"),
            autoAdvance: $(jq -r '.playback.autoAdvance' "$DEFAULTS")
        )
EOF

# --- Segments (default locale, backward-compat flat accessor) ---
{
  echo
  echo "        static let segments: [Segment] = ["
  jq -r --arg loc "$DEFAULT_LOCALE" '.locales[$loc].segments[] | "            Segment(key: \(.key | @json), displayKey: \(.displayKey | @json)),"' "$DEFAULTS"
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

# --- Default moments (default locale, backward-compat flat accessor) ---
{
  echo
  echo "        static let defaultMoments: [MomentDefinition] = ["
  jq -r --arg loc "$DEFAULT_LOCALE" '.locales[$loc].defaultMoments[] | "            MomentDefinition(key: \(.key|@json), nameKey: \(.nameKey|@json), shortNameKey: \(.shortNameKey|@json), colourKey: \(.colourKey|@json), segment: \(.segment|@json), autoAdvanceToNext: \(.autoAdvanceToNext|tostring), sortOrder: \(.sortOrder)),"' "$DEFAULTS"
  echo "        ]"
} >> "$OUT_FILE"

# --- Demo moments (default locale, backward-compat flat accessor) ---
{
  echo
  echo "        static let demoMoments: [MomentDefinition] = ["
  jq -r --arg loc "$DEFAULT_LOCALE" '.locales[$loc].demoMoments[] | "            MomentDefinition(key: \(.key|@json), nameKey: \(.nameKey|@json), shortNameKey: \(.shortNameKey|@json), colourKey: \(.colourKey|@json), segment: \(.segment|@json), autoAdvanceToNext: \(.autoAdvanceToNext|tostring), sortOrder: \(.sortOrder)),"' "$DEFAULTS"
  echo "        ]"
} >> "$OUT_FILE"

# --- Locale templates (per-region segments/defaultMoments/demoMoments) ---
{
  echo
  echo "        static let localeTemplates: [String: LocaleTemplate] = ["
  for LOC in $(jq -r '.locales | keys[]' "$DEFAULTS"); do
    echo "            \"$LOC\": LocaleTemplate("
    echo "                segments: ["
    jq -r --arg loc "$LOC" '.locales[$loc].segments[] | "                    Segment(key: \(.key|@json), displayKey: \(.displayKey|@json)),"' "$DEFAULTS"
    echo "                ],"
    echo "                defaultMoments: ["
    jq -r --arg loc "$LOC" '.locales[$loc].defaultMoments[] | "                    MomentDefinition(key: \(.key|@json), nameKey: \(.nameKey|@json), shortNameKey: \(.shortNameKey|@json), colourKey: \(.colourKey|@json), segment: \(.segment|@json), autoAdvanceToNext: \(.autoAdvanceToNext|tostring), sortOrder: \(.sortOrder)),"' "$DEFAULTS"
    echo "                ],"
    echo "                demoMoments: ["
    jq -r --arg loc "$LOC" '.locales[$loc].demoMoments[] | "                    MomentDefinition(key: \(.key|@json), nameKey: \(.nameKey|@json), shortNameKey: \(.shortNameKey|@json), colourKey: \(.colourKey|@json), segment: \(.segment|@json), autoAdvanceToNext: \(.autoAdvanceToNext|tostring), sortOrder: \(.sortOrder)),"' "$DEFAULTS"
    echo "                ]"
    echo "            ),"
  done
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
