# Adding a new language

For when a translation is commissioned for a new market (French, German, Spanish, etc.).

## Steps

1. **Translate `localisation/en.json` into a new file** with the same key set:
   ```
   localisation/fr.json    # French
   localisation/de.json    # German
   localisation/es.json    # Spanish
   ```
   Translator returns the same JSON structure, translated values only. Keys MUST match `en.json` exactly.

2. **Drop the file into the repo.** The codegen scripts auto-discover any `xx.json` in `localisation/`:
   - **iOS:** generates a multi-locale `.xcstrings` String Catalog (TODO: extend `generate-swift.sh` for multi-locale — currently English-only)
   - **Android:** generates `app/src/main/res/values-xx/strings.xml`

3. **Smoke-test:** in a sim/emulator, switch system language to the new locale and verify every screen.

4. **Bump VERSION** — MINOR (additive).

5. **Commit, tag, push** as in [ADDING-A-TRACK.md](ADDING-A-TRACK.md) steps 5–7.

## Translator handover

Export `en.json` flat; send to translator. Specify:
- Same JSON shape
- Preserve dotted key names exactly
- Sentence case for body text, title case for buttons/CTAs (or per-locale convention)
- Watch for tokens like `{count}` if/when ICU plurals are added

## Known limitations (v1.x)

- `localisation/en.json` is a flat key→string map. No ICU plurals, no gender, no rich text. Add ICU plurals as a future MAJOR if a locale needs them (e.g. Russian plural categories).
- iOS multi-locale `.xcstrings` emission is not yet implemented. Add to `generate-swift.sh` when the first non-English locale lands.
