# Changelog

All notable changes to `wedding-player-shared`. Format follows [Keep a Changelog](https://keepachangelog.com/).

## Unreleased

(no changes pending)

## v1.0.33 — 2026-05-08

Folds the last three iOS hardcoded-copy overrides back into shared content so iOS and Android stay in sync.

### Localisation (`localisation/en.json`)
- `onboarding.personalise.body` — value updated to "Tell us who's getting married and roughly when. We'll personalise the walkthrough so it reads as your ceremony." (was the older "Just your names and roughly when…" stub which iOS had been overriding inline).
- `nowPlaying.finalTrack` — value updated from "FINAL TRACK" to "CEREMONY ENDS AFTER THIS". Reads the moment as well as the track context: when there is no further populated moment to advance to, this *is* the end of the ceremony's audio.
- `setupGuide.tips.body.prefix` / `setupGuide.tips.body.suffix` — new pair flanking an inline `?` SF Symbol in the SetupGuideCard tip-cards section.
- `setupGuide.darkMode.title` / `setupGuide.darkMode.body.prefix` / `setupGuide.darkMode.body.suffix` — new keys for the SetupGuideCard dark-mode section, with the body split around an inline settings-icon SF Symbol.

`setupGuide.tips.detail` is left in place but unused on iOS; Android can adopt the same prefix/suffix split when it picks up the SetupGuideCard.

### Verification
- `swiftc -parse` clean on regenerated `SharedContent.generated.swift`.
- iOS swap of remaining hardcoded strings to `String.shared("…")` lands in the same iOS commit that bumps the submodule pin.

## v1.0.31 — 2026-05-08

Onboarding redesign — content side. Adds the strings and the cross-platform telemetry contract for the new role-aware first-run flow shipping in iOS Build 48 (Phases 2–6) and the Android port.

### Localisation (`localisation/en.json`)
- `onboarding.splash.subtitle` — "Ceremony Music" (gold subtitle on the new animated splash).
- `onboarding.role.*` — six keys covering the role-gate header, body, and the two card titles + bodies (couple / wedding-professional).
- `onboarding.personalise.*` — eleven keys covering the new single-screen `CouplePersonalisationView` (header, body, section labels, name placeholders, date-mode toggle, CTA, footnote).
- `onboarding.pro.demoComplete.*` — nine keys covering the Wedding-Professional variant of the demo-complete view (header, body, two option rows with title/body, three CTAs).
- `demo.couple.partner1` / `partner2` — "Nicola" / "Alex" — canonical demo couple names so iOS auto-personalisation and Android auto-personalisation match.
- `paywall.link.couple` — "I'm just planning my own wedding →" — reciprocal cross-link added to `VenuePaywallView`.

All additions; no existing keys touched.

### Docs
- `docs/onboarding-events.md` — full TelemetryDeck contract for the new flow. Documents the canonical `UserRole` raw values (`couple`, `wedding_professional`), the demo-complete action raw values (`setup`, `replay`, `reset`, `keep_demo`), every event name + payload schema, the `source` values for paywall events, and the funnels worth building. **Both platforms must follow this verbatim** — TelemetryDeck aggregates by string match.

### Verification
- `swiftc -parse` clean on regenerated `SharedContent.generated.swift`.
- iOS Build 48 swap of hardcoded strings to `String.shared("…")` lands in the same iOS PR that bumps the submodule pin.

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
