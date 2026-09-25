# CAUGHT ON CAMERA 📸

> Explore a strange place, notice paranormal anomalies, photograph them
> before they disappear, and build a collection of photographic evidence.

A mobile-first multiplayer Roblox MVP. The whole loop is **move + one big
PHOTO button**. It is not a pet simulator, a clicker, a tycoon or an RNG
hatcher. The progression is a collection album of things you actually saw
and caught on camera.

| | |
|---|---|
| **Core loop** | Lobby → 8-minute round in the **DEAD MALL** → Evidence Report → repeat |
| **Understand in 5 s** | "📸 Spot something WRONG. Take a PHOTO." (lobby board + first-round hint) |
| **Controls** | Mobile: PHOTO button next to jump · PC: Left Click / E · Gamepad: R2 / X |
| **Map** | Main Hall, Food Court, Toy Store, Arcade, Cinema, Bathrooms, Parking Garage, Storage Hallway (built from code) |
| **Anomalies** | 19 anomalies across 8 rarity tiers, one behaviour module each |
| **Events** | Paranormal Surge, Blackout, False Alarm, Rare Anomaly (random or bought for the whole server) |
| **Collection** | Anomaly Album (silhouettes for undiscovered), Photo Roll, Dark Room showcase |
| **Saving** | DataStore with session locking, retries, autosave, BindToClose |

## Documentation

| Document | Contents |
|---|---|
| [`docs/EXPLORER_HIERARCHY.md`](docs/EXPLORER_HIERARCHY.md) | Exact Roblox Studio Explorer hierarchy |
| [`docs/SCRIPTS.md`](docs/SCRIPTS.md) | All 56 scripts: name, type, exact location, source file |
| [`docs/SETUP.md`](docs/SETUP.md) | Studio setup (Rojo or copy-paste), monetization IDs, admin commands, adding anomalies |
| [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md) | Mobile/PC controls, photo validation, multiplayer, Fake Player, rounds, saving, passes, products, Surge, security |

Quick start: open a Baseplate, run `rojo serve`, connect, enable *Studio
Access to API Services*, press Play, type `/round start`.

## The anomalies

Odds are derived from `Weight` in `AnomalyConfig` ("1 in N spawn rolls").

| Anomaly | Rarity | Odds | What happens |
|---|---|---|---|
| Reverse Clock | Common | 1 / 4 | One of the mall's stopped clocks ticks and spins backwards |
| Floating Shopping Cart | Common | 1 / 5 | A cart lifts off the floor, bobbing and turning |
| Fake Exit | Common | 1 / 5 | An EXIT sign flickers, tilts and points into a wall |
| Moving Door | Unusual | 1 / 12 | A door appears where none exists and creaks open onto darkness |
| Walking Painting | Unusual | 1 / 12 | A figure in a painting moves closer whenever *you* look away (client-side) |
| Blinking Lights | Unusual | 1 / 13 | A zone's lights blink ···---···; a figure is revealed in the dark phases |
| Watching Mannequin | Rare | 1 / 36 | A new mannequin creaks around to face the nearest player |
| Faceless Shopper | Rare | 1 / 38 | An ambient shopper keeps walking, without a face |
| Frozen Crowd | Rare | 1 / 43 | All shoppers freeze mid-step except one (frozen ones are decoys) |
| Wrong Reflection | Epic | 1 / 110 | Your clone appears in the bathroom mirror, staring and waving |
| Ceiling Watcher | Epic | 1 / 110 | A long-limbed creature on the ceiling tracks you, then skitters |
| Fake Player | Epic | 1 / 130 | A copy of a real player with a misspelled name moonwalks towards you |
| Smiling Player | Mythic | 1 / 430 | A player gets a huge grin, but only on *other* players' screens |
| The One Behind You | Mythic | 1 / 430 | A figure follows one player: "DO NOT TURN AROUND." It vanishes when they look |
| The Photographer | Nightmare | 1 / 2,600 | Photograph it and it photographs YOU back: flash, black screen, badge |
| The Observer | Impossible | 1 / 100,000 | A colossal eye fills the skylight and follows you, red tint |
| The Night Manager | ??? | 1 / ??? | "ATTENTION SHOPPERS. THE MALL IS NOW CLOSED." Red lights, blinking manager |
| Glowing Eyes | Common | Blackout only | Blinking eyes in dark corners |
| Shadow Runner | Unusual | Blackout only | A black silhouette sprints down corridors |

Rarity tiers: Common, Unusual, Rare, Epic, Mythic, Nightmare, Impossible, ???
(`RarityConfig`). Epic+ captures are announced to the server; Nightmare+
trigger a ~3.5-second non-blocking dramatic reveal ("IMPOSSIBLE ANOMALY /
THE OBSERVER / 1 / 100,000 / FOUND BY NAME").

## Photo system

The client sends only its camera CFrame. `PhotoService` on the server:

1. rate-limits (camera cooldown + 6 requests / 4 s),
2. replaces the camera origin with the head if it is too far away or behind a wall,
3. checks every live anomaly for **distance**, **angle from the centre of view**
   (bigger anomalies are more forgiving), **line of sight** (raycasts) and camera ability,
4. grades **1-5 stars** (distance + centring + a "caught it early" bonus; a valid photo is never below 1★),
5. pays Evidence (`base × stars × new-discovery ×2 × group-photo bonus × first-photographer bonus`),
   updates the album, Photo Roll, round stats, badges and announcements.

Anyone can photograph the same anomaly. The first photographer gets ⚡ FIRST!,
and having other players in the shot gives 👥 GROUP PHOTO. Re-shooting the
same anomaly can raise your best star rating.

## Progression & monetization

- **Evidence** buys cameras and upgrades that change *how* you play:
  FastCam (cooldown 1.2 s → 0.55 s), Zoom Lens (range), Steady Grip (framing
  tolerance), Sixth Sense (whisper when something spawns nearby). NightCam,
  ThermalCam and GlitchCam are wired through `CameraConfig.Abilities` +
  `AnomalyConfig.RequiredAbility` and shown as *Coming soon*.
- **Game Passes**: Fast Camera, Extra Album Storage, Bigger Dark Room, VIP
  Photographer (name tag, chat tag, gold camera, gold Dark Room). None of them
  change anomaly odds.
- **Developer Products**: Paranormal Surge and Blackout (whole server
  benefits, "👁️ NAME CAUSED A PARANORMAL SURGE"), Small/Medium Evidence Packs.
  Granted only in an idempotent `ProcessReceipt`. No loot boxes, no paid anomalies.
- All IDs live in `ReplicatedStorage/Config/MonetizationConfig`.

## Architecture

```
ReplicatedStorage/Config    data-only tuning (anomalies, rarities, cameras, monetization, game)
ReplicatedStorage/Modules   Net (remotes), Signal, Cleaner, Format, PhotoMath
ServerScriptService/Main    boots services in order: Map → Data → Monetization → Economy →
                            Character → NPC → Event → Anomaly → Photo → DarkRoom → Round → Admin
ServerScriptService/Anomalies/Behaviors   one ModuleScript per anomaly (Spawn/Update/OnCaptured/Despawn)
StarterPlayerScripts/ClientMain + Controllers   UI + client-only effects, driven by ClientState
```

Adding an anomaly is one config entry plus one behaviour module; see
[`docs/SETUP.md`](docs/SETUP.md#adding-a-new-anomaly-about-5-minutes).

**Performance.** Anomalies are anchored/welded, non-colliding and cleaned up
by a `Cleaner`. At most 4-9 exist at once. There are 6 low-cost NPCs on
straight lanes (no pathfinding). Behaviour updates are batched at 10 Hz.
There are no particles and no per-frame raycasts: raycasts only happen when
the shutter is pressed. About 24 shadowless lights. Streaming-safe teleports.

**Security.** Remotes only carry requests. Evidence, discoveries, cameras,
upgrades and purchases are decided on the server, every argument is
type-checked, and every remote is rate-limited.

## Verification status

- Every script passes the `luau-lsp` type checker against the full Roblox API
  definitions, with a Rojo sourcemap so cross-module requires resolve.
- The pure config/math modules (odds, stars, rewards, formatting) were run
  under the standalone Luau runtime. For example, a new 3★ Rare pays exactly
  $3,200 and The Observer shows "1 / 100,000".
- The game has **not** been play-tested inside Roblox Studio yet, because
  Studio is not available in the environment this was built in. Please run
  through [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md) before
  publishing.
