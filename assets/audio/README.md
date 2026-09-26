# Audio assets (original, generated)

Every sound in CAUGHT ON CAMERA, synthesised from scratch by
`tools/sfx/generate_sfx.py`. No samples or third-party audio are used.

| File | Upload? | Paste the id into |
|---|---|---|
| `banks/Equipment.ogg` | **yes** | `SoundConfig.Banks.Equipment` |
| `banks/Player.ogg` | **yes** | `SoundConfig.Banks.Player` |
| `banks/World.ogg` | **yes** | `SoundConfig.Banks.World` |
| `banks/Loops.ogg` | **yes** | `SoundConfig.Banks.Loops` |
| `loops/*.ogg` | optional | `SoundConfig.Loops.<Name>` (only if you want separate loop files) |

Where each sound sits inside a bank is recorded in
`src/ReplicatedStorage/Config/SoundBankLayout.lua`. That file is generated
together with these files, so if you regenerate the audio, upload the banks again.

Full guide: [`docs/SOUND_DESIGN.md`](../../docs/SOUND_DESIGN.md).
