# test-vectors

Cross-platform fixtures and guards that keep the iOS (Swift) and Android (Kotlin) Player apps
in lockstep with the shared content, and prove the v3.0 multi-wedding migration is lossless.

## Codegen guard (live now)

`verify-codegen.sh` asserts:

1. **Determinism** — `generate-swift.sh` / `generate-kotlin.sh` produce byte-identical output on
   repeated runs.
2. **Frozen locale templates** — `content/defaults.json`'s `GB` and `US` locale templates still
   match the committed snapshots below. Catches an accidental edit to a shipped template.

```
./test-vectors/verify-codegen.sh
```

- `expected-codegen-GB.json` — the UK template (phases `daytime`/`evening`, 6 default + 3 demo moments).
- `expected-codegen-US.json` — the US template (phases `ceremony`/`cocktail`/`reception`).

If a template change is **intentional**, regenerate the snapshot:
`jq -S '.locales.GB' content/defaults.json > test-vectors/expected-codegen-GB.json` (and `US`).

## Migration round-trip fixture (added in Loop B)

`golden-moments-v2.json` — a representative **pre-v3** `moments.json` (the single-wedding on-disk
format), covering all three track types (Apple Music / Originals / local), both phases, trims,
fade-in/out, looping, crossfade. It is the fixture for:

- iOS `WeddingPlayerTests/CeremonyMigrationRoundTripTests` — decode into the renamed
  `CeremonyMoment`/`Track`, re-encode, assert **byte-identical wire keys** (proves `CodingKeys`
  froze `segment` etc.), then run the full migration into Core Data and assert no field lost.
- Android `MomentSerializationRoundTripTest` — the same, via Gson `@SerializedName`, then Room.
- Cross-platform: the same golden file must decode identically on both platforms.

**Deliberately deferred to Loop B** rather than authored here: the fixture must match the *real*
iOS encoder output exactly (field presence/omission for nil optionals depends on the model's
`Encodable`). It will be captured from the actual `Track.swift` / `CeremonyMoment.swift` encoder
(or a real pre-v3 install) in Loop B, not hand-written, to avoid a subtly-wrong fixture.
