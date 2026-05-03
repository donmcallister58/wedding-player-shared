# Adding or changing a user-facing string

For copy edits, new screens, A/B variants, accessibility labels.

## Naming convention

`<area>.<element>.<role>` — lowercase, dotted, kebab-case for multi-word.

Areas in use:
- `app` — global (e.g. `app.name`)
- `segment` — moment segments
- `colour` — palette display names
- `moment` — default moment names + short names (suffix `.name` / `.short`)
- `demo` — demo mode copy + demo track titles/artists
- `paywall` — IAP screen
- `onboarding` — first-run flow
- `live` — operator/live mode (transport, now playing)
- `setup` — setup mode
- `error` — error messages
- `accessibility` — VoiceOver / TalkBack labels

Example: `live.transport.next.compact` → "Next" (compact form for high Dynamic Type).

## Steps

1. **Edit `localisation/en.json`**. Add or modify the key + value.

2. **Smoke-test codegen** locally (see [CHANGING-A-DEFAULT.md](CHANGING-A-DEFAULT.md) step 3).

3. **Bump VERSION**:
   - **PATCH** — value edit on an existing key
   - **MINOR** — new key
   - Renames are breaking — either ship a deprecation period (keep old key as alias for one minor version) or **MAJOR** bump

4. **Commit, tag, push** as in [ADDING-A-TRACK.md](ADDING-A-TRACK.md) steps 5–7.

5. New keys are unused until a call site references them. Adding a key without a call site is harmless — it just sits in the table until needed. Add the call site (`Text(.shared("…"))` on iOS, `shared("…")` on Android) as part of the feature work that needs the string.
