# Changelog

All notable changes to `wedding-player-shared`. Format follows [Keep a Changelog](https://keepachangelog.com/).

## Unreleased

(no changes pending)

## v1.0.62 - 2026-05-25

Trim the `where-to-find-music-breadcrumb` Help item from three steps to two. The third step ("Each route has a Guide button that opens the full walkthrough at weddingplayer.app/music with screenshots and step-by-step instructions.") felt redundant: users following the breadcrumb to the Get-more-music sheet will see the per-section Guide pills directly, and don't need to be told about them in advance.

### Content (`content/help-content.json`)
- `where-to-find-music-breadcrumb` steps trimmed from 3 to 2.
- `version` bumped 1.5 -> 1.6.

## v1.0.61 - 2026-05-25

Collapse the `where-to-find-music` section to a single breadcrumb item now that the new in-app Get-more-music sheet (iOS commit `3480a61`, with per-section `/music/*` Guide pills shipped in #352) is the natural discovery surface for this content. Five long item walkthroughs (~50 lines of help-content) duplicated what the sheet plus the website music topic hub already cover better.

### Content (`content/help-content.json`)
- Removed: `buy-music-no-subscription`, `buy-music-itunes-store-ios`, `buy-music-amazon`, `buy-music-qobuz`, `buy-music-other-stores` (the five original Build 49 items).
- Added: single `where-to-find-music-breadcrumb` item titled "Where do I find more music?" pointing users at the in-app Get-more-music sheet plus the weddingplayer.app/music hub.
- `version` bumped 1.4 -> 1.5.

Help & Support stays focused on in-app mechanics; purchase walkthroughs live on the website where they can be updated without an app review cycle.

## v1.0.60 - 2026-05-25

Loop copy sweep after Build 55 #345/#229 enabled Loop on multi-track moments. Two help/demo strings still spoke about Loop as a single-track-only feature with track-level semantics. Now updated to reflect the moment-level reality and match the in-app toggle label "Loop Moment".

### Content (`content/help-content.json`)
- Playlist-editor screen tip `Loop track` -> `Loop Moment`: icon `edit` -> new `loop` token, context rewritten to describe the moment-level wrap behaviour (all tracks play in order, then wrap back to the first) with the red looping indicator on playback.
- `version` bumped 1.3 -> 1.4.

### Icons (`content/icons.json`)
- New `loop` token: iOS `repeat`, Android `Repeat`. Matches the in-app loop indicator SF Symbol on iOS.

### Localisation (`localisation/en.json`)
- `demo.tip.register.stopped.context`: dropped the "if you have a single track" caveat; now mentions Loop Moment + multi-track wrap behaviour.

## v1.0.59 - 2026-05-25

Help-content URL refresh after the weddingplayer.app music-hub revamp. The three remaining `weddingplayer.app/blog/how-to-add-music-to-wedding-player` references in `where-to-find-music` now point to dedicated music-hub sub-pages instead of the redirected hub overview, so couples land directly on the relevant content.

### Content (`content/help-content.json`)
- `buy-music-no-subscription` overview link: `/blog/how-to-add-music-to-wedding-player` -> `/music/individual-tracks`.
- `buy-music-itunes-store-ios` "if it doesn't appear" link: `/blog/how-to-add-music-to-wedding-player` -> `/music/apple-music` (closer topical match: the troubleshooting is about Apple Music Library sync, not buying).
- `buy-music-other-stores` walkthrough link: `/blog/how-to-add-music-to-wedding-player` -> `/music/individual-tracks`.
- `version` bumped 1.2 -> 1.3.

### Companion
- Carried alongside 080d61c (already on main, untagged before this release): Amazon UK MP3 URL replacement in `en.json`. Bundled into v1.0.59.

## v1.0.58 - 2026-05-24

Wedding Player Originals catalogue metadata expansion. Adds six new fields per track (`genre`, `mood`, `instrumentation`, `tempo`, `vocal`, `dateAdded`) and refreshes every track's `sourceHash` and `previewVersion` to the latest preview generation. Powers the filterable browse view on `weddingplayer.app/music`. iOS and Android consumers can pick this up at any time; the new fields are additive and platforms ignore unknown keys.

### Catalogue (`catalogue/catalogue.json`)
- 36+ tracks now carry: `genre` (Classical, Acoustic, Folk, Pop, etc.), `mood` (array, e.g. Romantic + Serene), `instrumentation` (Piano, Guitar, Mixed, etc.), `tempo` (Slow / Moderate / Fast), `vocal` (boolean), `dateAdded` (YYYY-MM-DD).
- Every `sourceHash` and `previewVersion` refreshed to the latest CDN preview generation (e.g. wp_002 v5 to v7).
- Net change: +433 lines, -74 lines.

### Companion
- `weddingplayer.app/music` page goes live with working filters once the website submodule is bumped to v1.0.58.

## v1.0.57 - 2026-05-24

New help section "Where to Find Music" covering DRM-free on-device track purchases for couples without an Apple Music subscription. Surfaces in iOS Help & Support, Android Help, and the website support page (after consumer submodule bumps).

### Content (`content/help-content.json`)
- `version` bumped 1.1 to 1.2.
- New section `where-to-find-music` with 5 items:
  - `buy-music-no-subscription` (both): "I don't have Apple Music. Where can I buy tracks?" Explains DRM-free, points to walkthrough.
  - `buy-music-itunes-store-ios` (ios): Buying on the built-in iTunes Store app.
  - `buy-music-amazon-mp3` (both): Buying on amazon.co.uk/music/MP3 via Safari/Chrome.
  - `buy-music-qobuz` (both): Buying via the native Qobuz app.
  - `buy-music-other-stores` (both): 7digital and file-format guidance (MP3/M4A both platforms, FLAC Android only).
- All items link to the full walkthrough at weddingplayer.app/blog/buy-drm-free-music-iphone-android.

### Companion deliverables (separate repos, not in this bump)
- New blog post `buy-drm-free-music-iphone-android.md` on the weddingplayer-site repo.
- Pointer added from existing post `how-to-add-your-own-music-files-to-wedding-player.md`.

## v1.0.43 — 2026-05-18

Trim editor help content for 2.1.4 (Build 50). New `?` button on the TrimEditSheet surfaces this content via `ScreenTipState.shared.show("trim-editor")`.

### Content (`content/help-content.json`)
- New `screenTips` entry `trim-editor` — five actions covering: set start/end points (sliders + mm:ss fields, auto-enable-fade-on-touch), fade in/out toggles (and where fade duration is set), preview buttons (From in-point / To out-point / Full trimmed clip, plus the AM-uses-main-player note), Reset Trim button (Build 50 #264), Save/Cancel persistence.

### Icons (`content/icons.json`)
- New `scissors` token — `ios: scissors` / `android: ContentCut`. Used by the new trim-editor screen tip; available for other surfaces that surface trim state.

### Not in this bump
- Hardcoded English strings from CHANGELOG #234, #236, #237, #240, #241 and the recent #257/#258/#260/#261/#262/#263/#264 still pending extraction to `localisation/en.json`. Logged for the next bump; functionality ships on iOS while strings stay inline.

## v1.0.35 — 2026-05-08

Last three "Aeroplane Mode" residues swept from `content/help-content.json`. The v1.0.27 sweep covered the body copy but left two screen-tip `context` fields and one `label` referring to the British spelling. Reads inconsistently with the system "Airplane Mode" label and the body text on the same screens.

### Content (`content/help-content.json`)
- Main Player tip — "Top of the screen shows whether **Airplane Mode** is on…" (was Aeroplane).
- Offline Readiness tip — `label` "Test in **Airplane** Mode" + matching `context` body (both were Aeroplane).

No `version` field bump on the JSON itself — the codegen pulls strings, not the file's `version`. Shared VERSION bumped 1.0.34 → 1.0.35 so platforms can pin a stable point.

## v1.0.34 — 2026-05-08

Telemetry contract correction — splash events renamed to match what both platforms actually send. No localisation, content, or codegen output changes.

### Docs (`docs/onboarding-events.md`)
- Renamed `splash_shown` → `splash_v2_shown`. Renamed `splash_skipped` → `splash_v2_skipped`. Both iOS and Android already send the `_v2` variants in code; the contract was the outlier.
- Updated the "First-run conversion" funnel to reference `splash_v2_shown`.
- Added a footnote explaining the `_v2` suffix: the V1 splash (gold ring + 8 confetti dots, light theme) shipped briefly on iOS Build 48 and was deleted in iOS commit `38dcda4` before any production telemetry accumulated. The suffix keeps a clean separation if a V3 design ever lands.

### Verification
- No code in either platform repo references the renamed events — the contract was previously documenting names that were never fired. Both platforms send `splash_v2_skipped` today; both will start sending `splash_v2_shown` in the same iOS / Android commits that bump this submodule pin.

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
