# Sound Design & Audio System

The goal of the audio in **CAUGHT ON CAMERA 📸** is simple: *players should be
able to tell that something is dangerous without seeing it.* Every item makes
real, physical sounds, every sound can be **heard by anomalies**, and some
anomalies are built entirely around sound.

- [1. Getting the audio into your game (4 uploads)](#1-getting-the-audio-into-your-game-4-uploads)
- [2. Architecture](#2-architecture)
- [3. The noise system](#3-the-noise-system)
- [4. Equipment sounds](#4-equipment-sounds)
- [5. Footsteps, doors and interactions](#5-footsteps-doors-and-interactions)
- [6. Sound-reactive anomalies](#6-sound-reactive-anomalies)
- [7. Deception, masking and silence](#7-deception-masking-and-silence)
- [8. 3D audio, occlusion, variation and acoustics](#8-3d-audio-occlusion-variation-and-acoustics)
- [9. Mixer and player settings](#9-mixer-and-player-settings)
- [10. Every sound path (placeholders)](#10-every-sound-path-placeholders)
- [11. Adding or replacing sounds](#11-adding-or-replacing-sounds)
- [12. Legal / originality](#12-legal--originality)

---

## 1. Getting the audio into your game (4 uploads)

The game ships with **original, procedurally synthesised audio** for every
sound (see [section 12](#12-legal--originality)). All 303 sound files (185 sound
paths with their random variations) are packed into **four files**, so you only
need four uploads. That keeps you far below Roblox's monthly audio upload limit,
which is small for accounts without ID verification.

| File | Contains | Paste the id into |
|---|---|---|
| `assets/audio/banks/Equipment.ogg` | Camera, Flashlight, EMF, Thermal, UV, Night Vision, handling | `SoundConfig.Banks.Equipment` |
| `assets/audio/banks/Player.ogg` | footsteps (10 surfaces × 6 variations), jumps, landings, 7 door types, interactions | `SoundConfig.Banks.Player` |
| `assets/audio/banks/World.ogg` | anomalies, thunder / HVAC / drips, UI | `SoundConfig.Banks.World` |
| `assets/audio/banks/Loops.ogg` | seamless loops: mall hum, rain, HVAC, Listener breathing, flashlight buzz, UV/NV hums, thermal scan, lobby + tension music | `SoundConfig.Banks.Loops` |

**Steps**

1. Upload the four `.ogg` files: Studio → **View → Asset Manager → Bulk Import**,
   or Creator Hub → Creations → Development Items → **Audio → Upload Asset**.
   Upload them to the **same owner as the experience** (your user account, or the
   group if the game belongs to a group). Otherwise the experience is not allowed
   to play them.
2. Wait for moderation to finish, then copy each asset id.
3. Open `ReplicatedStorage/Config/SoundConfig` and paste the ids:
   ```lua
   SoundConfig.Banks = {
       Equipment = "rbxassetid://1111111111",
       Player    = "rbxassetid://2222222222",
       World     = "rbxassetid://3333333333",
       Loops     = "rbxassetid://4444444444",
   }
   ```
4. Press Play. Every sound now plays from the banks. Each sound is a
   `PlaybackRegion` of its bank, and every random variation is its own region.

**Before you upload anything the game is not silent.** Every one-shot sound
has a pitched built-in Roblox fallback (`rbxasset://sounds/...`). Only the
music and ambience beds stay silent until the Loops bank is uploaded.

**Optional: separate loop files.** `assets/audio/loops/*.ogg` holds the same 10
loops as separate files. If you prefer a dedicated file for a loop (for example
to reuse the music elsewhere), upload it and put its id in `SoundConfig.Loops.<Name>`.
A dedicated loop file wins over the bank.

**Regenerating the audio** (only needed after changing a recipe):

```bash
pip install -r tools/sfx/requirements.txt       # numpy + soundfile
python tools/sfx/generate_sfx.py                 # writes assets/audio + SoundBankLayout.lua
python tools/sfx/generate_sfx.py --preview out/  # also writes every sound as a .wav to listen to
```

The generator is deterministic (fixed seeds). It rewrites
`ReplicatedStorage/Config/SoundBankLayout.lua` with the new regions, so **after
regenerating you must upload the banks again**, because their timings changed.

---

## 2. Architecture

```
            ReplicatedStorage/Config/SoundConfig        ← every sound: ids, volume, pitch range,
                          │                                roll-off, SoundGroup, noise value
            ReplicatedStorage/Config/SoundBankLayout    ← generated: path → bank + regions
                          │
            ReplicatedStorage/Modules/SoundResolver     ← path → SoundId (+region), random pitch/volume
                          │
 SERVER                   │                        CLIENT
 AudioService ── WorldSound remote ─────────────▶  AudioController  (plays everything, 3D + occlusion)
   ▲  └─ NoiseService:Emit (anomalies hear it)       ▲   ▲   ▲
   │                                                 │   │   └ FootstepController (material steps)
 EquipmentService  InteractionService                │   └ EquipmentController (EMF beeps, buzz loops,
 EnvironmentService  AnomalyKit.PlaySound3D          │                          thermal, UV, NV, hotbar)
 PhotoService (shutter/flash noise)                  └ PhotoController (autofocus, shutter, zoom)
```

- **SoundConfig** is the single source of truth. Sounds are addressed by path,
  e.g. `Camera.Shutter`, `EMF.Level5`, `Player.Footstep.Metal`,
  `Door.Security.Slam`, `Anomaly.ListenerAttack`.
- **The server never creates Sound objects.** `AudioService:Play(path, where, opts)`
  sends `WorldSound` to the players within the sound's roll-off distance, and
  also calls `NoiseService:Emit` so anomalies can hear it. Sounds you make
  yourself play instantly on your own client (predicted) and are excluded from
  your own `WorldSound`.
- **Device states replicate as Tool attributes** (`On`, `EMFLevel`,
  `EMFDistort`, `Interference`). Every client simulates everyone's EMF beeps,
  LEDs, flashlight buzz and hums locally, so they are perfectly in sync and
  cost no network traffic per beep.
- **Resolution order** for a path: `entry.Ids` (explicit uploads) →
  `SoundConfig.Loops[entry.Loop]` → bank region from `SoundBankLayout` →
  built-in `Fallback`.

---

## 3. The noise system

`NoiseService` (server) keeps a short-lived list of noise events
(`GameConfig.Noise.EventLifetime` = 2.5 s). Anomalies with a `Hearing`
profile call `NoiseService:Listen(position, hearing)` and get the loudest
event they perceive:

```
perceived = intensity × MapAcoustics.NoiseCarry × Hearing.Kinds[kind]
            × (1 − distance / Hearing.Radius)
            × WallDamping ^ walls          (0.5 per wall, max 2 raycasts)
            − EnvironmentalNoiseLevel × MaskingFactor (0.6)
heard if perceived ≥ Hearing.Threshold
```

**Noise values** (from the design spec; all in `SoundConfig` / `GameConfig` / `CameraConfig`):

| Source | Noise | Kind |
|---|---|---|
| Camera shutter: Starter / FastCam / old ThermalCam | 0.15 / 0.22 / 0.30 | `Shutter` |
| Silent Shutter upgrade lv 1 / lv 2 | ×0.6 / ×0.33 (→ 0.05) | `Shutter` |
| Camera flash | 0.10 × upgrade multiplier | `Flash` |
| Autofocus beep / broken autofocus | 0.04 / 0.08 | `Focus` |
| Flashlight / UV toggle | 0.05 | `FlashlightClick` |
| Flashlight malfunction (flicker, electrical failure, rapid toggling) | 0.15 | `FlashlightMalfunction` |
| Broken flashlight (bulb failure) | 0.30 | `FlashlightMalfunction` |
| EMF detector | 0.012 × level | `EMF` |
| Sneak / walk / run step (every 0.5 s) | 0.03 / 0.10 / 0.35 | `Sneak` / `Footstep` / `Run` |
| Jump landing / heavy landing | 0.40 / 0.60 | `Land` |
| Door open / quiet close / **slam** | 0.15 / 0.08 / **0.60** | `DoorOpen` / `DoorClose` / `DoorSlam` |
| Chat message ("talking") | 0.20 | `Voice` |
| Lockers, drawers, breaker, generator, elevator… | 0.05 – 0.50 | `Interaction` |
| Radio / ringing payphone | 0.20 – 0.30 | `Radio` / `Phone` |

Footstep noise is multiplied by the floor surface
(`GameConfig.Noise.SurfaceMultiplier`: metal ×1.3, water ×1.25, glass ×1.15,
wood ×1.1, carpet ×0.6…). Movement noise is computed on the server from the
character's real velocity, so a client cannot fake being quiet.

**Crouch / sneak** (Left Ctrl or C) halves the speed and drops step noise from
0.10 to 0.03. **Running** (Left Shift, L3 or the mobile RUN button) is fast
but 0.35 per step.

---

## 4. Equipment sounds

Hand items are real Roblox **Tools**, so other players see you holding them
and hear them in 3D. Switching items (keys 1-6 / hotbar) plays *unequip →
handling → equip* and locks the new item for 0.3 s.

### Camera 📷
| Moment | Sounds |
|---|---|
| Aiming (autofocus) | distance in the middle of the frame changes → `Focus` beep, then `LensMove` "zzzt". The server hears it (`Focus` noise). |
| Taking a photo | `ButtonClick` → `Shutter` + `FlashTrigger` → `FlashCharge` whine. Other players hear shutter + flash from your camera. |
| Zoom (Q / L2 / 🔍) | `ZoomIn` / `ZoomOut` motor + `LensMove` |
| **Broken autofocus** | aiming at an anomaly with Danger ≥ 0.6 within 55 studs: "beep… beep… **BEEEEP**" (`FocusBroken`) + `Static` + screen glitch. The entity hears it. |
| Capture | `CaptureSuccess`, or `CaptureRare` for Rare and above |
| Battery | `BatteryLow` at 20 %, `BatteryEmpty`, `Error` when shooting with an empty battery |
| Interference | `Glitch`, `Static` |

### Flashlight 🔦 and UV light 🟣
- Equip / unequip, firm on/off click, battery insert / remove.
- **Paranormal buzz**: only near dangerous anomalies (`AnomalyService:GetDangerNear`).
  The light buzzes (3D loop, others hear it), flickers, and can suffer an
  **electrical failure**: "CLICK… nothing" for a few seconds.
- Empty battery → `BulbFailure`. Rapid toggling (3 toggles in 3 s) counts as malfunction noise.
- UV light: deeper click, ballast "tzzz" and hum; reveals residue prints only inside your own beam.

### EMF detector 📟
| Level | Beep interval | Pitch |
|---|---|---|
| 1 | 1.70 s | 880 Hz |
| 2 | 1.15 s | 1046 Hz |
| 3 | 0.75 s | 1244 Hz |
| 4 | 0.38 s | 1480 Hz |
| 5 | 0.12 s | 1760 Hz, driven |

Very dangerous anomalies (EMF 5 and Danger ≥ 0.7) **distort** the beeps
(`Distort`, `BrokenBeep`). When the anomaly vanishes the detector falls
**silent instantly**, and that silence is itself a warning.

### Thermal scanner 🌡️
`Activate` (relay + spin-up whirr + confirm chirps), `ScanLoop` (fan + sensor
ticks), `HeatDetected` when a cold anomaly enters the view cone, `TargetLock`
when it is centred, `Interference` + `ERR` readout next to strong entities,
`Shutdown`, `BatteryWarning`.

### Night vision 🥽
`PowerOn` = **"BEEP—WHIRR"** (beep + rising charge whine), faint high `Hum`,
`BatteryWarning`, `Static` near danger, `SignalLoss` very close to strong
anomalies, `PowerOff`.

---

## 5. Footsteps, doors and interactions

**Footsteps**: `FootstepController` plays material-based steps for every
nearby humanoid (players, shoppers, humanoid anomalies). The step rhythm
follows the actual speed. The surface comes from the floor material
(`SoundConfig.MaterialSurfaces`) or a `FootstepSurface` attribute on the floor
part. Surfaces: Concrete, Wood, Metal, Tile, Carpet, Water, Grass, Glass,
Hospital, School. Each has 6 variations with ±10 % pitch and ±15 % volume
jitter. Step volume by mode: sneak 0.3, walk 0.6, run 1.0. Landings play
`Player.Land` or `Player.HeavyLand`. Roblox's default character sounds are
replaced by an empty `RbxCharacterSounds` script.

In the Dead Mall: marble (tile) in the Main Hall and Bathrooms, carpet in the
Cinema and Arcade, metal in the Storage Hallway, concrete in the Parking
Garage, puddles (water) under the leaking skylight and in the garage, the
Food Court's wooden stage, and broken glass at the Toy Store entrance.

**Doors** (`InteractionService`): every door has **Open** (E), **Close
quietly** (hold E, noise 0.08) and **Slam** (F, noise 0.60, heard up to 160
studs). The door swings away from you. Door types, set with the `DoorType`
attribute: **Wood**, **Metal**, **Security** (mall security, bolt motor and
deny buzz), **Hospital** and **School** (push bars), **Motel** (door chain) and
**Locker**. Each type has Open, Close, Slam, Locked, Handle and Creak sounds.

**Interactions**: battery pickup/use, Evidence collect, upgrade, purchase,
lockers, drawers, elevator button + ding, security computer, key pickup,
unlock, generator start, breaker on/off, radio static + voice, payphone
ring + pickup.

---

## 6. Sound-reactive anomalies

| Anomaly | Reacts to | Behaviour |
|---|---|---|
| **The Listener** (Rare) | running, landings, door slams/opens, shutter, focus, talking, radio/phone, interactions, EMF. It barely reacts to flashlight clicks, and **not at all to the light itself**. | Slow breathing loop. It hears a noise, clicks (`ListenerAlert`), hunts at speed 15 towards the source, then searches. If it reaches you: jumpscare, 1.6 s stun, battery drain. Sneak and it never notices you. |
| **Light Creature** (Unusual) | flashlight clicks / malfunctions | Hides in dark spots and hisses. A flashlight or UV **beam** on it burns it away (shriek). Clicking a light nearby makes it relocate. |
| **The Photographer** (Nightmare) | autofocus, shutter, flash | Autofocus makes it turn and **stare**. A shot or a flash makes it flash back at you (`FlashedBy`). Photographing it photographs *you* back. |
| **Echo** (Unusual) | any sound you **repeat** (3× within 8 s) | It moves somewhere else and replays your own sounds (shutter, steps, doors…), or whispers and voices. |
| **Mimic** (Rare) | – | Imitates gameplay sounds using the *real* sound paths: shutter, footsteps walking up behind you, a door opening at a real door, EMF beeps, flashlight clicks, a battery pickup, and a giggle. |

Hearing profiles live in `AnomalyConfig` (`Hearing = { Radius, Threshold, Kinds }`).
Any new anomaly can become sound-reactive by adding one.

---

## 7. Deception, masking and silence

- **Phantom sounds** (`EnvironmentService`, every 26-55 s in a round): footsteps
  on the floor above you or walking up behind you, a camera shutter, a
  flashlight click, a door opening at a real door, EMF beeps, a battery pickup,
  knocking inside a wall. They use exactly the same paths as real sounds, so
  "was that my teammate?"
- **Environmental masking**: thunder raises the environmental noise level to
  **0.8** for 2.5 s (0.8 × 0.6 = 0.48 subtracted from player noise). Running
  (0.35) is completely hidden and even a slam is reduced to 0.12. **Wait for
  the thunder, then run past the thing that hunts by sound.** HVAC bursts
  (0.45) mask noise within 60 studs of the vent for 6 s.
  `NoiseService:GetEnvironmentalNoiseLevel(position)` exposes the value.
- **Silence rule**: when an anomaly with Danger ≥ 0.7 is within 55 studs, the
  music and ambience fade out. Silence means *something is close*.

---

## 8. 3D audio, occlusion, variation and acoustics

- **3D**: every spatial sound uses `RollOffMode = InverseTapered` with its own
  `RollOff = { min, max }` (for example a whisper 3-40, the shutter 8-90, a slam 10-160,
  The Observer's drone 60-500).
- **Occlusion**: the client counts walls between the camera and the sound (up
  to 2 raycasts). Each wall multiplies the volume by 0.55 and adds an
  `EqualizerSoundEffect` that cuts the highs by −12 dB per wall. Doors and
  walls muffle naturally.
- **Variation**: several recorded variations per sound where it matters
  (footsteps 6, shutter 3, doors 2…), plus subtle random pitch (`Pitch`
  range) and volume (`VolumeJitter`) on every play. Nothing sounds copy-pasted.
- **Zone acoustics** (`SoundConfig.ZoneAcoustics`): the client switches
  `SoundService.AmbientReverb` per zone (Hangar in the Main Hall, Bathroom,
  ParkingLot, StoneCorridor…) and plays the zone's ambience beds.
- **Map feel** (`SoundConfig.MapAcoustics`): the Dead Mall echoes and noise
  carries a bit (`NoiseCarry` 1.1). Hospital (metal carries far), School and
  Motel (rain masking) presets are ready for future maps.

---

## 9. Mixer and player settings

`AudioController` builds `SoundService.COC_Mixer`:

```
Master ─┬─ Music         (MusicVolume)
        ├─ Ambience      (AmbienceVolume, plus the Ambience on/off toggle)
        ├─ PlayerSFX     footsteps, doors, interactions
        ├─ EquipmentSFX  (EquipmentVolume)
        ├─ AnomalySFX
        ├─ Voice         (VoiceVolume) whispers, radio, anomaly voices
        ├─ Jumpscares    (JumpscareVolume)
        └─ UI
```

Players change **Master, Music, Ambience, Equipment, Voice and Jumpscare**
volume in *Album → SETTINGS* (10 % steps). The values are saved in the
DataStore and clamped to 0..1 on the server.

---

## 10. Every sound path (placeholders)

Every path below is a placeholder until you upload the banks. Paths are
generated from `SoundConfig` (185 in total). The `x` column shows the number of
random variations in the bank.

| Category | Paths |
|---|---|
| Camera | Equip, Unequip, Shutter ×3, Focus, FocusBroken, ZoomIn, ZoomOut, LensMove ×2, ButtonClick, FlashCharge, FlashTrigger, BatteryLow, BatteryEmpty, CaptureSuccess, CaptureRare, Glitch ×2, Static ×2, Error |
| Flashlight | Equip, Unequip, On ×2, Off ×2, ButtonClick, BatteryInsert, BatteryRemove, LowBattery, Buzz (loop), Flicker ×2, ElectricalFailure, BulbFailure, Interference ×2 |
| EMF | Equip, Unequip, PowerOn, PowerOff, Level1-Level5, Distort ×2, BrokenBeep ×2 |
| Thermal | Equip, Unequip, Activate, Shutdown, ScanLoop (loop), TargetLock, HeatDetected, BatteryWarning, Interference ×2 |
| UV | Equip, Unequip, On ×2, Off ×2, Hum (loop), BatteryChange, Interference ×2 |
| NightVision | PowerOn, PowerOff, Activation, Hum (loop), BatteryWarning, Static ×2, SignalLoss |
| Equipment | Handling ×2, Holster ×2 |
| Player | Footstep.{Concrete, Wood, Metal, Tile, Carpet, Water, Grass, Glass, Hospital, School} ×6, Jump ×2, Land ×2, HeavyLand |
| Door.{Wood, Metal, Security, Hospital, School, Motel, Locker} | Open ×2, Close ×2, Slam ×2, Locked, Handle, Creak ×2 |
| Interaction | BatteryPickup, BatteryUse, EvidenceCollect, Upgrade, Purchase, LockerOpen, LockerClose, DrawerOpen, DrawerClose, ElevatorButton, ElevatorDing, Computer, KeyPickup, Unlock, GeneratorStart, BreakerOn, BreakerOff, RadioStatic ×2, RadioVoice ×2, PhoneRing, PhonePickup |
| Anomaly | Sting, Vanish, ClockTick ×2, DoorCreak ×2, Whisper ×3, Scratch ×2, Knock ×3, Skitter ×2, Groan ×2, ObserverDrone, NightManagerChime, PhotographerFlash, ListenerBreath (loop), ListenerAlert, ListenerAttack, LightCreatureHiss ×2, LightCreatureShriek, EchoWhisper ×2, EchoVoice ×2, MimicGiggle ×2, Jumpscare |
| Environment | Thunder ×2, LightningCrack, HVACBurst, DistantBang ×2, Drip ×3, PAStatic |
| Ambience (loops) | MallHum, RainSkylight, HVAC |
| Music (loops) | Lobby, Tension |
| UI | Button, Toast, Announce, Reveal, NewDiscovery, Fail, Whisper ×2, Heartbeat, Error, Stinger |

The only values you ever paste are the 4 `SoundConfig.Banks.*` ids (plus,
optionally, `SoundConfig.Loops.*` and per-sound `Ids`).

---

## 11. Adding or replacing sounds

- **Replace one sound with your own upload**: set its `Ids`, e.g.
  `Shutter = S({ Ids = { "rbxassetid://123", "rbxassetid://456" }, ... })`. Several ids become
  random variations. Explicit ids always win over the bank.
- **Add a new sound**: add an entry to the right category in `SoundConfig`
  (give it a `Fallback` so it plays before upload), add a recipe with the
  same path in `tools/sfx/recipes_*.py` (`@reg("Category.Name", variations)`),
  run the generator and re-upload the bank.
- **Make an action audible to anomalies**: give the entry `Noise` and
  `NoiseKind`, and play it through `AudioService:Play(path, where, { Source = player })`.
- **Play a sound from server code**: `AudioService:Play("Door.Metal.Slam", part, {})`.
  From an anomaly behaviour: `ctx.Kit.PlaySound3D(part, "Anomaly.Knock")`.
- **Play a sound on the client**: `AudioController:Play(path, where?, { Volume, Speed })`
  (`where` = nil for 2D, a Vector3, a BasePart or an Attachment).

---

## 12. Legal / originality

- Every sound in `assets/audio` is **synthesised from scratch** by
  `tools/sfx` (numpy oscillators, filtered noise, modal "impact" synthesis,
  formant voices that are unintelligible by design, and original procedural
  music). No samples, recordings, sound libraries, or audio from films,
  games, YouTube or TikTok were used. You own them like the rest of this
  project's code.
- The fallback sounds are Roblox's own built-in `rbxasset://sounds/` content,
  which ships with every Roblox client.
