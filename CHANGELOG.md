# Changelog

All notable changes to `wedding-player-shared`. Format follows [Keep a Changelog](https://keepachangelog.com/).

## Unreleased

(no changes pending)

## v1.0.0 — 2026-05-03

Initial release. First cut of the shared-content repo, consumable from both iOS and Android via submodule + build-time codegen.

**Shipped in:** _pending iOS Phase 2 — will ship as part of iOS 2.1.2 (Build 46+) and Android 2.1.2_

### Catalogue
- 35-track manifest (`catalogue/catalogue.json`) mirrored from `cdn.weddingplayer.app/music/catalogue.json` as of 2026-05-03
- 35 preview clips (`catalogue/previews/wp_002.mp3` … `wp_036.mp3`) at 15s each
- Note: track numbering starts at `wp_002` — `wp_001` does not exist

### Demo
- 5 demo MP3s (`demo/audio/`) with kebab-case canonical filenames
- Demo manifest (`demo/manifest.json`) with id, filename, displayTitleKey, artistKey, durationSecs

### Defaults
- `content/defaults.json` schemaVersion 1
- 12-colour Ethereal Ceremony palette with light/dark adaptive hex pairs + tab variants
- `colourAutoSequence` for automatic colour assignment on new moments
- 6 default moments (Guests Arriving / Walking The Aisle / Signing The Register / The Couple Exit / Wedding Breakfast / Drinks Reception)
- 3 demo moments (subset, used in demo mode only)
- 2 segments (daytime, evening)
- IAP product id, CDN base URL, playback defaults (5s fade, 3s crossfade, autoAdvance true)
- Per-platform overrides scaffolded — none currently set

### Localisation
- `localisation/en.json` — stub corpus (~40 keys) covering app name, segments, colours, default + demo moment names, demo track titles/artists, paywall basics, onboarding page titles
- Full corpus (~150 keys) to be authored during iOS Phase 2a as views are refactored

### Scripts
- `scripts/codegen/generate-swift.sh` — emits `SharedContent.generated.swift` from defaults.json + en.json
- `scripts/codegen/generate-kotlin.sh` — emits `SharedContent.generated.kt` and optionally `strings.xml`; applies `platformOverrides.android`
- `scripts/generate-previews.sh` — copied from iOS repo. Regenerates 15s preview clips from Google Drive masters.
- `scripts/sync-to-cdn.sh` — placeholder; to be wired up post-launch

### Docs
- `README.md`, `CHANGELOG.md`, `VERSION`
- `docs/ADDING-A-TRACK.md`, `docs/CHANGING-A-DEFAULT.md`, `docs/ADDING-A-STRING.md`, `docs/ADDING-A-LANGUAGE.md`

### Verification
- `swiftc -parse` clean on generated Swift
- Generated Kotlin compiles structurally (full Kotlin compile happens during Android build wiring in Phase 3)
- Generated `strings.xml` is valid XML with Android resource-naming conventions (dotted/hyphenated keys → underscored)
