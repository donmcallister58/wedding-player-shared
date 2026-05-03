# Changing a default moment, colour, or segment

For renames, palette tweaks, default playback values, or adding/removing colours.

## Steps

1. **Edit `content/defaults.json`**.

2. If the change introduces or renames keys, **add corresponding entries to `localisation/en.json`** (any text the user sees comes from there).

3. **Smoke-test codegen** locally:
   ```bash
   ./scripts/codegen/generate-swift.sh /tmp/swift-out
   ./scripts/codegen/generate-kotlin.sh /tmp/kotlin-out /tmp/strings-out
   cat /tmp/swift-out/SharedContent.generated.swift
   ```

4. **Bump VERSION** per semver:
   - **PATCH** — pure value tweaks (hex change, copy edit on an existing key)
   - **MINOR** — new colour, new default moment (additive, old apps still build)
   - **MAJOR** — rename or remove a key, change `schemaVersion`

5. **Commit, tag, push** as in [ADDING-A-TRACK.md](ADDING-A-TRACK.md) steps 5–7.

## Special case — adding a new colour

Colour `key` becomes user-visible JSON in user `moments.json` files. Once shipped, the key cannot be renamed without a migration. Choose carefully (lowercase, no spaces, semantic name).

## Special case — Android-specific override

If a colour or value renders poorly on Android, add a `platformOverrides.android` map rather than changing the base value:

```json
{
  "key": "cyan",
  "lightHex": "#D4968A",
  "platformOverrides": {
    "android": { "lightHex": "#CC8E83" }
  }
}
```

iOS keeps using `lightHex`; Android codegen applies the override.
