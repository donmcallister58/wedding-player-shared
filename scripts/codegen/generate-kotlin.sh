#!/usr/bin/env bash
# generate-kotlin.sh — produce SharedContent.generated.kt from defaults.json + en.json
#
# Usage:  ./generate-kotlin.sh <output-dir> [<strings-xml-output-path>]
#
# Reads:  ../content/defaults.json, ../localisation/en.json (relative to this script)
# Writes: <output-dir>/uk/playerapps/weddingplayer/shared/SharedContent.generated.kt
#         <strings-xml-output-path>/strings.xml  (if path supplied)
#
# Per-platform overrides: applies any defaults.json `platformOverrides.android` field-by-field
# on top of base values (currently used for colours).

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <output-dir> [<strings-xml-output-path>]" >&2
  exit 1
fi

OUT_DIR="$1"
STRINGS_XML_DIR="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULTS="$REPO_ROOT/content/defaults.json"
STRINGS="$REPO_ROOT/localisation/en.json"
VERSION="$(cat "$REPO_ROOT/VERSION")"

PKG_DIR="$OUT_DIR/uk/playerapps/weddingplayer/shared"
mkdir -p "$PKG_DIR"
OUT_FILE="$PKG_DIR/SharedContent.generated.kt"

[ -f "$DEFAULTS" ] || { echo "Missing: $DEFAULTS" >&2; exit 1; }
[ -f "$STRINGS"  ] || { echo "Missing: $STRINGS"  >&2; exit 1; }

# --- Kotlin source ---
cat > "$OUT_FILE" <<EOF
// GENERATED — DO NOT EDIT.
// Regenerated from wedding-player-shared@v$VERSION on each build.
// Source: content/defaults.json + localisation/en.json

package uk.playerapps.weddingplayer.shared

object SharedContent {

    data class Segment(val key: String, val displayKey: String)

    data class Colour(
        val key: String,
        val displayKey: String,
        val lightHex: String,
        val darkHex: String,
        val tabLightHex: String,
        val tabDarkHex: String
    )

    data class MomentDefinition(
        val key: String,
        val nameKey: String,
        val shortNameKey: String,
        val colourKey: String,
        val segment: String,
        val autoAdvanceToNext: Boolean,
        val sortOrder: Int
    )

    data class Playback(
        val fadeDurationSecs: Double,
        val crossfadeSecs: Double,
        val autoAdvance: Boolean
    )

    object Defaults {
        const val schemaVersion: Int = $(jq -r '.schemaVersion' "$DEFAULTS")
        const val cdnBaseUrl: String = $(jq -r '.cdnBaseURL | @json' "$DEFAULTS")
        const val fullAccessProductId: String = $(jq -r '.iap.fullAccessProductId | @json' "$DEFAULTS")
        val playback = Playback(
            fadeDurationSecs = $(jq -r '.playback.fadeDurationSecs' "$DEFAULTS"),
            crossfadeSecs = $(jq -r '.playback.crossfadeSecs' "$DEFAULTS"),
            autoAdvance = $(jq -r '.playback.autoAdvance' "$DEFAULTS")
        )
EOF

{
  echo
  echo "        val segments: List<Segment> = listOf("
  jq -r '.segments[] | "            Segment(key = \(.key|@json), displayKey = \(.displayKey|@json)),"' "$DEFAULTS"
  echo "        )"
} >> "$OUT_FILE"

# Colours — apply android overrides per-field
{
  echo
  echo "        val colours: List<Colour> = listOf("
  jq -r '
    .colours[]
    | . as $c
    | (.platformOverrides.android // {}) as $ov
    | "            Colour(key = \($c.key|@json), displayKey = \($c.displayKey|@json), lightHex = \(($ov.lightHex // $c.lightHex)|@json), darkHex = \(($ov.darkHex // $c.darkHex)|@json), tabLightHex = \(($ov.tabLightHex // $c.tabLightHex)|@json), tabDarkHex = \(($ov.tabDarkHex // $c.tabDarkHex)|@json)),"
  ' "$DEFAULTS"
  echo "        )"
} >> "$OUT_FILE"

{
  echo
  echo "        val colourAutoSequence: List<String> = listOf("
  jq -r '.colourAutoSequence[] | "            \(.|@json),"' "$DEFAULTS"
  echo "        )"
} >> "$OUT_FILE"

{
  echo
  echo "        val defaultMoments: List<MomentDefinition> = listOf("
  jq -r '.defaultMoments[] | "            MomentDefinition(key = \(.key|@json), nameKey = \(.nameKey|@json), shortNameKey = \(.shortNameKey|@json), colourKey = \(.colourKey|@json), segment = \(.segment|@json), autoAdvanceToNext = \(.autoAdvanceToNext|tostring), sortOrder = \(.sortOrder)),"' "$DEFAULTS"
  echo "        )"
} >> "$OUT_FILE"

{
  echo
  echo "        val demoMoments: List<MomentDefinition> = listOf("
  jq -r '.demoMoments[] | "            MomentDefinition(key = \(.key|@json), nameKey = \(.nameKey|@json), shortNameKey = \(.shortNameKey|@json), colourKey = \(.colourKey|@json), segment = \(.segment|@json), autoAdvanceToNext = \(.autoAdvanceToNext|tostring), sortOrder = \(.sortOrder)),"' "$DEFAULTS"
  echo "        )"
  echo "    }"
} >> "$OUT_FILE"

{
  echo
  echo "    object Strings {"
  echo "        fun en(key: String): String = enTable[key] ?: key"
  echo
  echo "        val enTable: Map<String, String> = mapOf("
  jq -r 'to_entries[] | select(.key | startswith("_") | not) | "            \(.key|@json) to \(.value|@json),"' "$STRINGS"
  echo "        )"
  echo "    }"
  echo "}"
  echo
  echo "fun shared(key: String): String = SharedContent.Strings.en(key)"
} >> "$OUT_FILE"

echo "Generated: $OUT_FILE ($(wc -l < "$OUT_FILE" | tr -d ' ') lines)"

# --- strings.xml (optional) ---
if [ -n "$STRINGS_XML_DIR" ]; then
  mkdir -p "$STRINGS_XML_DIR"
  XML="$STRINGS_XML_DIR/strings.xml"
  {
    echo '<?xml version="1.0" encoding="utf-8"?>'
    echo '<!-- GENERATED — DO NOT EDIT. Regenerated from wedding-player-shared on each build. -->'
    echo '<resources>'
    # Convert dotted keys to underscored (Android resource naming)
    # Escape XML special chars: &, <, >, ', "
    jq -r '
      to_entries[]
      | select(.key | startswith("_") | not)
      | "    <string name=\"" + (.key | gsub("\\."; "_") | gsub("-"; "_")) + "\">" + (.value | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("'\''"; "&apos;") | gsub("\""; "&quot;")) + "</string>"
    ' "$STRINGS"
    echo '</resources>'
  } > "$XML"
  echo "Generated: $XML"
fi
