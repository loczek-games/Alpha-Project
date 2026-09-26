# Audio

All sounds are original, procedurally generated (`tools/sfx/generate_sfx.py`), and play
through one authoritative pipeline: `SoundConfig` (definitions) → `SoundResolver`
(picks a source) → `AudioService` (server) / `AudioController` (client).

## Mixer

`SoundService.Master` holds the SoundGroups `Music`, `Ambience`, `EquipmentSFX`,
`PlayerSFX`, `AnomalySFX`, `Jumpscares`, `Voice` and `UI`. SETTINGS › AUDIO drives
their volumes per player.

## Where each sound comes from

For every path (e.g. `Camera.Shutter`) the resolver tries, in order:

1. `Ids` – explicit asset ids in `SoundConfig`
2. `Loop` – its own uploaded loop file (`assets/audio/loops/`)
3. **Bank** – a slice of an uploaded sound bank (`assets/audio/banks/*.ogg`)
4. **Fallback** – a built-in Roblox sound, so nothing is ever silent

Every asset is preloaded with `ContentProvider`. A missing or failed asset prints
`[AudioService] Failed sound: <path>` and that sound moves on to its next source.

## Manual step: upload the 4 banks (once)

Roblox only plays audio uploaded to your account/group, so the banks cannot ship
inside the repository:

1. Creator Dashboard › Development Items › Audio › upload
   `assets/audio/banks/Equipment.ogg`, `Player.ogg`, `World.ogg`, `Loops.ogg`.
2. Either paste the ids into `SoundConfig.Banks`, **or** (no code change) set the
   attributes `SoundBank_Equipment`, `SoundBank_Player`, `SoundBank_World`,
   `SoundBank_Loops` on `SoundService` in Studio (`rbxassetid://123…`).

Until then the built-in fallbacks play.

## Testing

* `/soundtest` (admin chat command) – prints the audio report to the client
  Output (F9) and plays one sound of every family.
* SETTINGS › AUDIO › TEST SOUND – same thing from the menu.
