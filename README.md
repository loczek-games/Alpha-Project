# CAUGHT ON CAMERA 📸

> Explore a strange place, notice paranormal anomalies, photograph them
> before they disappear, and build a collection of photographic evidence.

A mobile-first multiplayer Roblox MVP. The whole loop is **move + one big
PHOTO button**. It is not a pet simulator, a clicker, a tycoon or an RNG
hatcher. The progression is a collection album of things you actually saw
and caught on camera.

| | |
|---|---|
| **Core loop** | P.I.A. HQ lobby → physical queue zone (1-6 investigators, parties stay together) → mission in the **DEAD MALL** (first person) → Evidence Report → back to HQ |
| **Understand in 5 s** | "📸 Spot something WRONG. Take a PHOTO." |
| **Controls** | Mobile: PHOTO button next to jump, 📷/🔍 button, tap the hotbar · PC: Left Click / E use item · 1-6 or mouse wheel switch item · Q zoom (or take the camera out) · Shift run · Ctrl/C sneak · Gamepad: R2 / X use, L1 / R1 switch, L2 zoom |
| **Lobby** | Physical P.I.A. HQ: mission portals with "[DEAD MALL] 0/6 PLAYERS" boards and a 15 s timer, equipment / camera lab / flashlight bench / archive / supply / party / invite / settings stations, the Dark Room |
| **Places** | Works as one place (Studio / single place) or as Lobby place + Gameplay place with reserved servers (`MapConfig.Places`) |
| **Map** | Dead Mall: Grand Hall (2 floors, balconies, bridges, escalators), Food Court + 5 restaurants, Supermarket, Electronics, Clothing, Toy Store, Arcade, Cinema/Theaters, Restrooms, Service Halls, Back of House, Security Room, Parking Garage, Entrance. Baked to `assets/baked/DeadMall.rbxm` |
| **Anomalies** | 52 anomalies: modular AI (Idle/Observe/Stalk/Search/InvestigateNoise/Follow/Hide/Chase/Attack/Disappear), floor + ceiling movers, reusable object behaviours, sound-reactive hunters, the Ceiling Crawler |
| **Jumpscares** | Per-anomaly first-person jumpscares, stylised blood (toggle), FULL/REDUCED intensity; downed → teammates revive |
| **Equipment** | DSLR-style camera with a live rear screen + first-person arms viewmodel, Flashlight (bench upgrades), EMF, Thermal, UV Light, Night Vision |
| **Audio** | Original synthesised sounds, SoundGroup mixer, preload + verification, fallback for every sound (`docs/AUDIO.md`) |
| **Social** | Parties (leader, ready, avatar, mic status), INVITE FRIENDS (SocialService) |
| **Monetization** | PRO CAMERA, TACTICAL FLASHLIGHT, INVESTIGATOR PACK, VIP INVESTIGATOR, skins, dark room decor, REVIVE, PARANORMAL SURGE. Everything gameplay-relevant is also reachable for free |
| **Saving** | DataStore with session locking, retries, autosave, BindToClose |

## Documentation

| Document | Contents |
|---|---|
| [`docs/EXPLORER_HIERARCHY.md`](docs/EXPLORER_HIERARCHY.md) | Exact Roblox Studio Explorer hierarchy |
| [`docs/SCRIPTS.md`](docs/SCRIPTS.md) | All 74 scripts: name, type, exact location, source file |
| [`docs/SETUP.md`](docs/SETUP.md) | Studio setup (Rojo or copy-paste), audio upload, monetization IDs, admin commands, adding anomalies |
| [`docs/AUDIO.md`](docs/AUDIO.md) | Mixer, where every sound comes from, uploading the 4 banks, `/soundtest` |
| [`docs/ANOMALY_MODELS.md`](docs/ANOMALY_MODELS.md) | Anomaly bodies: overrides, catalog bundles, procedural rigs, manual insertion |
| [`docs/SOUND_DESIGN.md`](docs/SOUND_DESIGN.md) | Audio architecture, noise values, equipment / door / footstep sounds, sound-reactive anomalies, every sound path |
| [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md) | Controls, photo validation, multiplayer, rounds, saving, passes, products, Surge, security, equipment, audio, noise |

Quick start: open `build/CaughtOnCamera.rbxl` (or `rojo serve` into a
Baseplate), enable *Studio Access to API Services*, press Play, walk into the
DEAD MALL portal (or type `/round start`). For the real audio,
upload the 4 files in `assets/audio/banks/` and paste their ids into
`SoundConfig.Banks` (until then built-in fallback sounds play).

## The anomalies

Odds are derived from `Weight` in `AnomalyConfig` ("1 in N spawn rolls"). Generated from the config:

| Anomaly | Rarity | Odds | Description |
|---|---|---|---|
| 🕰️ Reverse Clock | Common | 1 / 12 | Every clock in the mall stopped at the same minute. This one is running backwards. |
| 🛒 Floating Shopping Cart | Common | 1 / 13 | An abandoned cart that forgot about gravity. |
| 🔀 Moving Exit | Common | 1 / 14 | The EXIT sign keeps moving. The exit it points to does not exist. |
| 👀 Glowing Eyes | Common | 1 / 15 | Only appears in a blackout. Two lights that blink back. |
| 🛒 Moving Cart | Common | 1 / 16 | Every time you look back, the cart is closer. |
| 🍔 Floating Food Tray | Common | 1 / 17 | Someone's last meal, spinning slowly above the table. |
| 🪑 Moving Chair | Common | 1 / 18 | A chair drags itself across the food court, always into your way. |
| 🛍️ Shopping Bag Movement | Common | 1 / 18 | The bag rustles. Something inside is dragging it towards you. |
| 🔴 Rolling Ball | Common | 1 / 21 | A child's ball rolls after you. Nobody threw it. |
| 🚪 Possessed Door | Unusual | 1 / 31 | It opens. It slams. Nobody is there. |
| 💡 Blinking Lights | Unusual | 1 / 33 | Three short, three long, three short. Something stands where the dark was. |
| 📺 TV Entity | Unusual | 1 / 33 | Every screen in the store switched on. They all show the same face. |
| 🏃 Shadow Runner | Unusual | 1 / 36 | Only appears in a blackout. Too fast to be a person. |
| 🖼️ Walking Painting | Unusual | 1 / 35 | The person in the painting moves whenever nobody is looking. |
| 🕹️ Possessed Arcade Machine | Unusual | 1 / 37 | PLAYER 2 HAS ENTERED THE GAME. |
| ☎️ Phone Caller | Unusual | 1 / 39 | A disconnected payphone is ringing. It is for you. |
| 😮 Ceiling Face | Unusual | 1 / 42 | A pale face pressed against the ventilation grille. Look up. |
| 🚨 Car Alarm | Unusual | 1 / 45 | The car has had no battery for years. Its alarm is screaming. |
| 📦 Flying Shelves | Unusual | 1 / 45 | The shelf shakes... and everything on it is thrown across the aisle. |
| 🗄️ Locker Knocking | Unusual | 1 / 45 | Knock. Knock. Knock. From the inside. |
| 🗿 The Statue | Unusual | 1 / 45 | The founder's statue always faces the entrance. Always faced. |
| 🔔 Store Alarm | Unusual | 1 / 45 | The anti-theft gates are screaming. Nothing walked through them. Nothing you can see. |
| 🦎 Light Creature | Unusual | 1 / 52 | Lives in the dark. Point a flashlight at it and it's gone. |
| 🎭 Echo | Unusual | 1 / 57 | Repeat a sound and it repeats it back... from somewhere else. |
| 🧍 Watching Mannequin | Rare | 1 / 87 | Its head turns to follow you. Only when you are not looking. |
| 😶 Faceless Shopper | Rare | 1 / 98 | A late shopper strolling through a closed mall. Look closer at the face. |
| 🛗 Fake Elevator | Rare | 1 / 100 | The elevator has been out of service since 1998. Ding. |
| 👥 Mannequin Group | Rare | 1 / 100 | The whole display moved closer. All of them. Together. |
| 📹 Security Camera Watcher | Rare | 1 / 100 | Every camera in the area turned to follow you. The monitors show someone standing behind you. |
| 🧍‍♂️ Black Figure Behind Glass | Rare | 1 / 110 | Outside the entrance glass, in the rain, someone is watching you. |
| 🚗 Someone In The Car | Rare | 1 / 110 | Someone is sitting in the driver's seat. Its head turns with you. |
| 🏪 Closed Store Opening | Rare | 1 / 120 | The shutter that has been locked for years is rising. The lights inside are on. |
| 👂 The Listener | Rare | 1 / 120 | Blind. It hunts by sound. Photograph it... if the shutter doesn't give you away. |
| 🛗 Escalator Figure | Rare | 1 / 130 | The dead escalator started moving. Someone is riding it up. |
| 🐀 Ratthew | Rare | 1 / 130 | The old food court mascot. It still lives in the kitchens. |
| 🎎 Walking Store Dummy | Rare | 1 / 130 | It only moves when nobody is looking. Keep looking. |
| 👄 Mimic | Rare | 1 / 140 | That camera click wasn't your teammate. Neither were those footsteps. |
| 🏬 Wrong Store | Rare | 1 / 140 | That store was never in this mall. It knows your name. |
| 🕷️ Ceiling Crawler | Epic | 1 / 220 | Long legs, a human face, and it lives on the ceiling. If you hear crawling above you, don't look up. |
| 🪞 Wrong Reflection | Epic | 1 / 260 | Your reflection is not copying you anymore. It is watching you. |
| 🧟 Possessed Customer | Epic | 1 / 290 | The last customer never left. Something else is walking in them now. |
| 😁 Smiling Entity | Epic | 1 / 290 | It never stops smiling. It only moves when you blink. |
| 👤 Mirror Double | Epic | 1 / 310 | It stepped out of the mirror wearing your face. It follows you everywhere. |
| 👥 Fake Player | Epic | 1 / 350 | It looks exactly like someone in this investigation. Almost exactly. |
| 🚪 Impossible Hallway | Epic | 1 / 390 | The employee hallway used to end in a wall. Now it just keeps going. |
| 🪪 Employee Only Entity | Mythic | 1 / 1,000 | EMPLOYEES ONLY. It still works the night shift. You are not staff. |
| 👻 The One Behind You | Mythic | 1 / 1,000 | It follows one investigator closely. Whatever you do, do not turn around. |
| 🦍 Parking Garage Stalker | Mythic | 1 / 1,000 | Something huge moves between the pillars on level B1. It is always one pillar closer. |
| 😃 Smiling Player | Mythic | 1 / 1,000 | One investigator is smiling far too wide. They have no idea. |
| 📷 The Photographer | Nightmare | 1 / 6,300 | It collects evidence too. Of you. |
| 👁️ The Observer | Impossible | 1 / 210,000 | Look up through the skylight. It has always been looking down. |
| 🕴️ The Night Manager | Unknown | 1 / ??? | Attention shoppers. The mall is now closed. |

Admin/test commands: `/spawn <Id>`, `/anomalies`, `/round start|end`, `/event surge|blackout|falsealarm|rare`,
`/jumpscare <Kind>`, `/soundtest`, `/revive`, `/battery`, `/equipment`, `/phantom`, `/thunder`.

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
- `lune run tools/test/validate.luau` checks the baked maps against the
  configs: every anomaly has its behaviour module, appearance and spawn
  fixtures/markers in its zones, the ceiling crawler node graph, every sound
  path used in code exists, lobby queue zones / stations / dark room, every
  equipment model and skin builds, shop products point at real items.
- **Headless play tests** run the real game code in Lune on the built place
  (`tools/test/engine.luau` + `place.luau` emulate the parts of the engine the
  game needs: signals, remotes between one server and one client, tools,
  pivots, services):
  - `lune run tools/test/playtest_full.luau`: server `Main` + every service
    and client `Loading` + `ClientMain` + every controller. A player joins, the
    loading screen goes away, they walk into the DEAD MALL queue zone, the
    mission starts, they take the camera out (keys, Q, mouse wheel), take a
    photo, and return to HQ.
  - `lune run tools/test/playtest_equipment.luau`: equipment and the
    first-person viewmodel in detail.
  Build first with `rojo build default.project.json --output build/CaughtOnCamera.rbxl`.
- Maps are baked with `lune run tools/bake/bake.luau` and were inspected with
  an offline renderer.
- The game has **not** been play-tested inside Roblox Studio (Studio is not
  available in the environment this was built in): run through
  [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md) before publishing.
