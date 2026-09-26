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
| **Controls** | Mobile: PHOTO button next to jump · PC: Left Click / E · Gamepad: R2 / X · hotbar 1-6 · Shift run · Ctrl/C sneak · Q zoom |
| **Map** | Main Hall, Food Court, Toy Store, Arcade, Cinema, Bathrooms, Parking Garage, Storage Hallway (+ a locked Security Office), built from code |
| **Anomalies** | 23 anomalies across 8 rarity tiers, one behaviour module each, 5 of them react to **sound** |
| **Equipment** | Camera, Flashlight, EMF Detector, Thermal Scanner, UV Light, Night Vision (real held Tools, batteries) |
| **Audio** | 185 original synthesised sounds in 4 upload files, 3D + occlusion, material footsteps, noise that anomalies hear |
| **Events** | Paranormal Surge, Blackout, False Alarm, Rare Anomaly (random or bought for the whole server) |
| **Collection** | Anomaly Album (silhouettes for undiscovered), Photo Roll, Dark Room showcase |
| **Saving** | DataStore with session locking, retries, autosave, BindToClose |

## Documentation

| Document | Contents |
|---|---|
| [`docs/EXPLORER_HIERARCHY.md`](docs/EXPLORER_HIERARCHY.md) | Exact Roblox Studio Explorer hierarchy |
| [`docs/SCRIPTS.md`](docs/SCRIPTS.md) | All 74 scripts: name, type, exact location, source file |
| [`docs/SETUP.md`](docs/SETUP.md) | Studio setup (Rojo or copy-paste), audio upload, monetization IDs, admin commands, adding anomalies |
| [`docs/SOUND_DESIGN.md`](docs/SOUND_DESIGN.md) | Audio architecture, noise values, equipment / door / footstep sounds, sound-reactive anomalies, every sound path |
| [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md) | Controls, photo validation, multiplayer, rounds, saving, passes, products, Surge, security, equipment, audio, noise |

Quick start: open a Baseplate, run `rojo serve`, connect, enable *Studio
Access to API Services*, press Play, type `/round start`. For the real audio,
upload the 4 files in `assets/audio/banks/` and paste their ids into
`SoundConfig.Banks` (until then built-in fallback sounds play).

## The anomalies

Odds are derived from `Weight` in `AnomalyConfig` ("1 in N spawn rolls").

| Anomaly | Rarity | Odds | What happens |
|---|---|---|---|
| Reverse Clock | Common | 1 / 5 | One of the mall's stopped clocks ticks and spins backwards |
| Floating Shopping Cart | Common | 1 / 5 | A cart lifts off the floor, bobbing and turning |
| Fake Exit | Common | 1 / 6 | An EXIT sign flickers, tilts and points into a wall |
| Moving Door | Unusual | 1 / 13 | A door appears where none exists and creaks open onto darkness |
| Walking Painting | Unusual | 1 / 14 | A figure in a painting moves closer whenever *you* look away (client-side) |
| Blinking Lights | Unusual | 1 / 15 | A zone's lights blink ···---···; a figure is revealed in the dark phases |
| Light Creature 🔊 | Unusual | 1 / 21 | Lurks in the dark and hisses; shine a flashlight on it and it burns away. Clicking a light makes it move |
| Echo 🔊 | Unusual | 1 / 25 | Repeat a sound three times and it replays *your* sounds from somewhere else |
| Watching Mannequin | Rare | 1 / 41 | A new mannequin creaks around to face the nearest player |
| Faceless Shopper | Rare | 1 / 44 | An ambient shopper keeps walking, without a face |
| Frozen Crowd | Rare | 1 / 49 | All shoppers freeze mid-step except one (frozen ones are decoys) |
| The Listener 🔊 | Rare | 1 / 49 | Eyeless, breathing, hunts by SOUND. Run, slam doors or shoot near it and it comes for you; sneak past or wait for thunder |
| Mimic 🔊 | Rare | 1 / 59 | Fakes gameplay sounds: a shutter, footsteps behind you, a door, EMF beeps, a flashlight click |
| Wrong Reflection | Epic | 1 / 120 | Your clone appears in the bathroom mirror, staring and waving |
| Ceiling Watcher | Epic | 1 / 120 | A long-limbed creature on the ceiling tracks you, then skitters |
| Fake Player | Epic | 1 / 150 | A copy of a real player with a misspelled name moonwalks towards you |
| Smiling Player | Mythic | 1 / 490 | A player gets a huge grin, but only on *other* players' screens |
| The One Behind You | Mythic | 1 / 490 | A figure follows one player: "DO NOT TURN AROUND." It vanishes when they look |
| The Photographer 🔊 | Nightmare | 1 / 3,000 | Hears your autofocus and stares; photograph it and it photographs YOU back: flash, black screen, badge |
| The Observer | Impossible | 1 / 100,000 | A colossal eye fills the skylight and follows you, red tint, a deep drone |
| The Night Manager | ??? | 1 / ??? | "ATTENTION SHOPPERS. THE MALL IS NOW CLOSED." Red lights, blinking manager |
| Glowing Eyes | Common | Blackout only | Blinking eyes in dark corners |
| Shadow Runner | Unusual | Blackout only | A black silhouette sprints down corridors |

🔊 = reacts to sound (see [`docs/SOUND_DESIGN.md`](docs/SOUND_DESIGN.md#6-sound-reactive-anomalies)).

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

## Equipment & sound

Hand items are real Roblox Tools that everyone sees you holding: **Camera**,
**Flashlight** and **EMF Detector** from the start, plus **Thermal Scanner**,
**UV Light** and **Night Vision** bought with Evidence. They run on batteries
found around the mall. Every action makes sound, and sound is gameplay:

- The camera autofocus goes "beep… zzzt… CLICK—FLASH", and near something
  dangerous it breaks: "beep… beep… BEEEEP".
- The flashlight buzzes and dies near strong entities, and the EMF beeps faster
  from level 1 to 5, then goes silent the moment the anomaly vanishes.
- Footsteps depend on the surface (10 surfaces) and speed. Running is loud,
  sneaking is nearly silent, and doors can be closed quietly or slammed.
- Noise travels to anomalies (walls dampen it, thunder masks it), and phantom
  sounds and the Mimic fake real sounds.
- 3D audio with wall occlusion, zone reverb, a silence rule near danger and
  six volume sliders.

## Progression & monetization

- **Evidence** buys cameras and upgrades that change *how* you play:
  FastCam (cooldown 1.2 s → 0.55 s), Zoom Lens (range), Steady Grip (framing
  tolerance), Sixth Sense (whisper when something spawns nearby), Silent
  Shutter (quieter shots for sound-hunting anomalies), plus the Thermal
  Scanner, UV Light and Night Vision equipment. NightCam,
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
ReplicatedStorage/Config    data-only tuning (anomalies, rarities, cameras, equipment, sounds, monetization, game)
ReplicatedStorage/Modules   Net (remotes), Signal, Cleaner, Format, PhotoMath, SoundResolver
ServerScriptService/Main    boots services in order: Map → Data → Monetization → Economy → Audio →
                            Noise → Character → Equipment → NPC → Event → Anomaly → Photo →
                            Interaction → Environment → DarkRoom → Round → Admin
tools/sfx                   procedural generator for every sound (numpy) → assets/audio + SoundBankLayout
ServerScriptService/Anomalies/Behaviors   one ModuleScript per anomaly (Spawn/Update/OnCaptured/Despawn)
StarterPlayerScripts/ClientMain + Controllers   UI + client-only effects, driven by ClientState
```

Adding an anomaly is one config entry plus one behaviour module; see
[`docs/SETUP.md`](docs/SETUP.md#adding-a-new-anomaly-about-5-minutes).

**Performance.** Anomalies are anchored/welded, non-colliding and cleaned up
by a `Cleaner`. At most 4-9 exist at once. There are 6 low-cost NPCs on
straight lanes (no pathfinding). Behaviour updates are batched at 10 Hz.
There are no particles. Raycasts run only for the shutter, for a few throttled
audio checks (occlusion ≤ 2 rays per 3D sound, a floor ray per footstep, and
autofocus every 0.3 s), and at 10 Hz for server noise. About 25 shadowless
lights. Streaming-safe teleports. Sounds are regions of 4 cached assets and
are destroyed when they finish.

**Security.** Remotes only carry requests. Evidence, discoveries, cameras,
upgrades and purchases are decided on the server, every argument is
type-checked, and every remote is rate-limited.

## Verification status

- Every script passes the `luau-lsp` type checker against the full Roblox API
  definitions, with a Rojo sourcemap so cross-module requires resolve.
- The pure config/math modules (odds, stars, rewards, formatting) were run
  under the standalone Luau runtime. For example, a new 3★ Rare pays exactly
  $3,200 and The Observer shows "1 / 100,000".
- Audio: a Luau test checks that all 185 `SoundConfig` paths have generated
  audio and a fallback, that footsteps have 4-8 variations, the resolver
  order (ids → loop file → bank region → fallback) and the required noise
  values. A Python check decodes the banks and confirms every region contains
  its sound with no bleed and that every loop is seamless.
- The game has **not** been play-tested inside Roblox Studio yet, because
  Studio is not available in the environment this was built in. Please run
  through [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md) before
  publishing.
