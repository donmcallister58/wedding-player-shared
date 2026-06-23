#!/usr/bin/env bash
# verify-codegen.sh — codegen-diff guard for the locale-indexed shared content.
#
# Asserts two things:
#   1. Determinism — regenerating Swift + Kotlin twice produces byte-identical output.
#   2. Frozen templates — content/defaults.json's GB and US locale templates still match
#      the committed test-vectors/expected-codegen-{GB,US}.json snapshots.
#
# Run from anywhere. Exit 0 = green.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULTS="$REPO_ROOT/content/defaults.json"
CODEGEN="$REPO_ROOT/scripts/codegen"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# 1. Determinism
"$CODEGEN/generate-swift.sh"  "$TMP/swift1"  >/dev/null
"$CODEGEN/generate-swift.sh"  "$TMP/swift2"  >/dev/null
"$CODEGEN/generate-kotlin.sh" "$TMP/kotlin1" >/dev/null
"$CODEGEN/generate-kotlin.sh" "$TMP/kotlin2" >/dev/null
diff -r "$TMP/swift1"  "$TMP/swift2"  >/dev/null || fail "Swift codegen not deterministic"
diff -r "$TMP/kotlin1" "$TMP/kotlin2" >/dev/null || fail "Kotlin codegen not deterministic"

# 2. Frozen locale templates
for LOC in GB US; do
  EXPECTED="$SCRIPT_DIR/expected-codegen-$LOC.json"
  [ -f "$EXPECTED" ] || fail "Missing expected snapshot: $EXPECTED"
  diff <(jq -S ".locales.$LOC" "$DEFAULTS") "$EXPECTED" >/dev/null \
    || fail "defaults.json locale '$LOC' drifted from expected-codegen-$LOC.json (update the snapshot intentionally if this was a deliberate template change)"
done

# 3. Flat accessors track the default locale
DEFAULT_LOCALE="$(jq -r '.defaultLocale' "$DEFAULTS")"
[ -n "$DEFAULT_LOCALE" ] || fail "defaultLocale missing from defaults.json"
[ -f "$SCRIPT_DIR/expected-codegen-$DEFAULT_LOCALE.json" ] \
  || fail "defaultLocale '$DEFAULT_LOCALE' has no expected-codegen snapshot"

echo "codegen guard GREEN: deterministic + GB/US templates frozen (default locale: $DEFAULT_LOCALE)"
