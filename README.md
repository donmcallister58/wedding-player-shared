# wedding-player-shared

Shared content for **Wedding Player** iOS + Android apps. Audio catalogue, demo bundles, default moments, colour palette, user-facing strings — single source of truth, consumed by both apps as a git submodule with build-time codegen.

Owner: Don McAllister · Private repo. Not for redistribution.

## What's in here

```
catalogue/      Canonical 35-track music catalogue manifest + 15s preview clips
demo/           5 sample MP3s + manifest used by demo mode in both apps
content/        defaults.json — moments, colour palette, segments, IAP, CDN base URL
localisation/   en.json — user-facing English copy (English-only at v1.x; future locales drop in next to en.json)
scripts/        Build helpers + codegen (generate-swift.sh, generate-kotlin.sh, generate-previews.sh, sync-to-cdn.sh)
docs/           Contributor guides per operation
```

What does **not** live here: full-quality track masters (Google Drive), Swift/Kotlin source files (generated at build time), platform-specific assets (app icons, screenshots), marketing assets.

## Consumers

- **iOS:** `donmcallister58/WeddingPlayer` — submodule at `Shared/`
- **Android:** `donmcallister58/WeddingPlayerAndroid` (path TBC) — submodule at `shared/`

Both apps pin to a tag (`v1.x.y`) in their `.gitmodules`, never to a branch. iOS ships first on a new shared tag; Android picks up the same tag once iOS is on the App Store.

## Quickstart for contributors

```bash
# Run codegen against the local content (smoke test)
./scripts/codegen/generate-swift.sh /tmp/wp-out
./scripts/codegen/generate-kotlin.sh /tmp/wp-out /tmp/wp-strings

# Regenerate catalogue previews after a track add/change
./scripts/generate-previews.sh \
  --source "/Users/donmcallister/Library/CloudStorage/GoogleDrive-don@playerapps.uk/My Drive/Wedding Player Catalogue Assets/tracks"
```

## How to make a change

1. Edit JSON / scripts / preview files in this repo
2. Update `CHANGELOG.md` under `## Unreleased`
3. Bump `VERSION` per [semver](https://semver.org/) — see Versioning below
4. Commit, push to `main`
5. `git tag vX.Y.Z && git push --tags`
6. Move the `## Unreleased` heading in `CHANGELOG.md` under the new version
7. Bump iOS submodule pointer to the new tag, ship iOS
8. After iOS App Store release: bump Android submodule pointer (same tag), ship Android

Detailed per-operation guides:
- [Add a track](docs/ADDING-A-TRACK.md)
- [Change a default](docs/CHANGING-A-DEFAULT.md)
- [Add a string](docs/ADDING-A-STRING.md)
- [Add a language](docs/ADDING-A-LANGUAGE.md)
- [Dynamic Type policy](docs/Dynamic%20Type%20Policy.md) (added by iOS Phase 2b)

## Versioning

Semver:
- **PATCH** — track additions, copy edits, preview regenerations, script bug fixes
- **MINOR** — new keys in defaults.json or en.json (additive, old apps still build)
- **MAJOR** — `schemaVersion` bump, removed/renamed JSON fields, breaking codegen API

The `## Unreleased` block in `CHANGELOG.md` should always include a `Shipped in:` line once apps go out, so a reader can see which app versions carried which content tag.

## Per-platform overrides

A few values render differently on iOS vs Android (different colour spaces, Material surface tinting). Such values can carry a `platformOverrides` map:

```json
{
  "key": "cyan",
  "lightHex": "#D4968A",
  "platformOverrides": {
    "android": { "lightHex": "#CC8E83" }
  }
}
```

iOS codegen ignores overrides; Android codegen applies `platformOverrides.android` on top of base values. Use sparingly — most values should be identical cross-platform.

## License

Private. Wedding Player content. © Don McAllister. All audio under licence to Wedding Player; not for redistribution.
