# Onboarding telemetry — cross-platform contract

Every TelemetryDeck event fired by the redesigned onboarding flow on iOS and Android. **Both platforms must use these exact event names and payload key names** — TelemetryDeck aggregates by string match, and a single funnel only works if both clients send the same shape.

TelemetryDeck app ID: `36B10888-9F6B-475A-8FC3-DA56BD63342A` (production, shared between iOS and Android).

## Conventions

- Event names: `snake_case`, present tense (`splash_shown`, `role_selected`).
- Payload keys: `snake_case`, scalars only (TelemetryDeck flattens to `additionalPayload`; values stringified).
- Payload values: keep under 250 chars (TelemetryDeck cap). Use canonical raw values from the role + action enums below — no free text.
- **No PII** in payloads. Never include partner names, wedding dates, emails, etc. The events describe *funnel position*, not the user.

## UserRole — canonical raw values

| Platform side | Source of truth | Value |
|---|---|---|
| iOS | `enum UserRole.couple` | `"couple"` |
| iOS | `enum UserRole.weddingProfessional` | `"wedding_professional"` |
| Android | (Kotlin enum equivalent) | `"couple"` / `"wedding_professional"` |

Use these strings everywhere a `role` payload is sent. Do not abbreviate (`pro`, `wp`) or vary case.

## Demo-complete action — canonical raw values

| Action | Couple variant | Pro variant |
|---|---|---|
| `setup` | Start Setup CTA | _n/a_ |
| `replay` | Replay demo CTA | Replay demo CTA |
| `reset` | _n/a_ | Reset for next wedding CTA |
| `keep_demo` | _n/a_ | Keep demo as starter CTA |

## Events

### Splash

| Event | Payload | Fires when |
|---|---|---|
| `splash_shown` | `is_first_launch: "true"\|"false"` | `AnimatedSplashView` appears (every cold launch). |
| `splash_skipped` | `elapsed_ms: <int>` | User taps splash before the auto-dismiss timer. |

### Role gate

| Event | Payload | Fires when |
|---|---|---|
| `role_gate_shown` | _none_ | `RoleSelectionView` appears (first launch + once for v1 → v2 migrators). |
| `role_selected` | `role: <UserRole raw>` | User picks a card. |

### Couple personalisation

| Event | Payload | Fires when |
|---|---|---|
| `personalisation_shown` | `role: "couple"` | `CouplePersonalisationView` appears. (Pros never see this — they're auto-personalised.) |
| `personalisation_completed` | `has_date: "true"\|"false"` | User taps Continue. `has_date` is false when "Date TBC" was on. |
| `personalisation_skipped_date` | _none_ | User toggles "Date TBC" on (independently of completing the form). |

### Demo

| Event | Payload | Fires when |
|---|---|---|
| `demo_play_started` | _none_ (legacy event, retained) | First demo track plays in a session. |
| `demo_completed` | `role: <UserRole raw>` | Final demo track finishes — fires once per demo run, before `DemoCompleteView` / `ProDemoCompleteView` is shown. |
| `demo_complete_action` | `role: <UserRole raw>`, `action: <action raw>` | User picks a CTA on the demo-complete view. See action raw values above. |

### Paywall

| Event | Payload | Fires when |
|---|---|---|
| `paywall_shown` | `role: <UserRole raw>`, `source: <string>`, `recommended_product: "fullaccess"\|"venue_annual"` | The paywall a user actually sees appears (couples → `PaywallView`, Pros → `VenuePaywallView`). |
| `paywall_alt_tier_clicked` | `from: <UserRole raw>`, `to: <UserRole raw>`, `source: <string>` | User taps the cross-link to the *other* tier's paywall. |
| `purchase_initiated` | `product: <productID>` (legacy, retained) | StoreKit `purchase()` begins. |
| `purchase_completed` | `product: <productID>` (legacy, retained) | Transaction verified successfully. |
| `purchase_prompt_shown` | `source: <string>` (legacy, retained) | Couples paywall presented — kept for back-compat with pre-v2 dashboards. |

`source` values (used in `paywall_shown` and `paywall_alt_tier_clicked`):

- `upgrade_banner` — generic upgrade banner in `PlayerSheetModifier`
- `go_live` — Go Live button on `MainPlayerView` / `iPadPlayerView`
- `event_manager` — Settings → Upgrade row
- `from_pro_paywall` — couples paywall opened via cross-link from Pro paywall

## Funnels worth building

- **First-run conversion** — cold launches → `splash_shown` → `role_gate_shown` → `role_selected` → (couple branch: `personalisation_completed`) → `demo_completed` → `paywall_shown` → `purchase_completed`. Watch drop-off at each step.
- **Role split** — count `role_selected` by `role`. Tells you the audience mix and informs how much copy / paywall energy to spend on each.
- **Demo replay rate** — `demo_complete_action{action:replay}` ÷ `demo_completed`. High replay = compelling demo or confusing CTAs; low replay + low setup = a cliff.
- **Pro reset vs keep** — split of `demo_complete_action{role:wedding_professional}` between `reset` and `keep_demo`. Informs whether to reorder the Pro CTAs.
- **Cross-tier crossover** — `paywall_alt_tier_clicked` counts. Low numbers means the role gate is doing its job; high numbers may indicate the role question is unclear.

## Versioning note

Adding new events here is additive — older clients ignore them. **Do not rename or repurpose an existing event** without a deliberate plan; that would silently corrupt funnels that span both old and new sessions.
