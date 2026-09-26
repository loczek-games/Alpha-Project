# Testing Checklist

Tools used below:
- **Device Emulator**: Test tab → Device (phone / tablet presets).
- **Local multiplayer**: Test tab → Clients and Servers → Local Server with 2-3 players.
- **Admin commands**: see `docs/SETUP.md` (`/round start`, `/spawn <Id>`, `/event surge`, ...).

Tick every box before publishing.

## 1. Mobile controls
- [ ] Phone emulator (e.g. iPhone 14, landscape): the PHOTO button sits left of the jump button, is at least thumb size, and never overlaps it.
- [ ] Tablet emulator: PHOTO button still left of (and not overlapping) the larger jump button.
- [ ] Tapping PHOTO plays button click → shutter + flash → flash recharge whine, white flash and a short freeze-frame; tapping the 3D world does **not** take a photo.
- [ ] The 🏃 RUN toggle sits above-left of PHOTO; the 🔍 zoom button appears only while the camera is held.
- [ ] Equipment sits in the normal Roblox hotbar (bottom centre); tapping a slot takes the item out, tapping the screen uses it. The held item and its battery are shown above the hotbar. With the flashlight held, the big button (touch) shows 🔦 LIGHT and toggles it.
- [ ] Holding the thumbstick and tapping PHOTO at the same time works (moving while shooting).
- [ ] The HUD covers only the edges: timer (top centre), Evidence (top right), Album/Camera (left), PHOTO (bottom right). The centre of the screen stays clear.
- [ ] Album and Camera Bag panels fit on a phone screen, scroll, and close with ✕.
- [ ] The capture card (polaroid) appears top-right and does not cover the PHOTO button.
- [ ] Text is readable on the smallest phone preset (UIScale minimum 0.7).

## 2. PC controls
- [ ] Left Mouse Button takes a photo; **E** takes a photo; the on-screen button also works and shows "CLICK / E".
- [ ] Standing at a door/locker (prompt visible): **E** uses the prompt and does NOT take a photo.
- [ ] Keys **1-9** / clicking a hotbar slot switch items (unequip + equip sounds, ~0.3 s before the item can be used); **left click** uses the held item (camera = photo); **Q** zooms (FOV 70 ↔ 38, zoom motor sound) or takes the camera out.
- [ ] Hold **Left Shift** = run (loud), hold **Left Ctrl / C** = sneak (slow, very quiet). Gamepad: L3 toggles run, L2 zooms.
- [ ] Clicking on UI (Album, Shop, tabs) does NOT also take a photo.
- [ ] Right-mouse camera rotation and zoom still work (max zoom is limited to 20 studs).
- [ ] Gamepad: R2 / X takes a photo.
- [ ] While the Album or Shop is open, clicking the world does not take photos.

## 3. Photo validation (server-authoritative)
Start a round (`/round start`) and `/spawn WatchingMannequin` (or any anomaly).
- [ ] Anomaly centred, close, visible → success card with name, rarity, odds, Evidence, stars, NEW DISCOVERY.
- [ ] Anomaly visible but at the screen edge → "Almost! Put it in the CENTRE 🎯", no reward.
- [ ] Anomaly centred but far away → "Too far away! Get closer 📏".
- [ ] Anomaly behind a wall/shelf → "Something is in the way 🧱".
- [ ] Pointing at empty space → "Nothing strange here... 🤔".
- [ ] Taking a photo just as an anomaly fades out still counts (0.5 s grace), but not later.
- [ ] Every valid photo gives at least ★☆☆☆☆; close + centred + early gives ★★★★★.
- [ ] Re-photographing the same anomaly instance: no Evidence, can raise "BEST" stars, max 3 shots → "You already have 3 shots of this one".
- [ ] Spamming PHOTO faster than the cooldown: extra shots are ignored (button bounces), the server never rewards them.
- [ ] Photos in the Lobby/Dark Room → "📸 Photos only count inside the DEAD MALL".
- [ ] Holding the flashlight and pressing the big button toggles the light instead of shooting; with empty hands it equips the camera.
- [ ] Camera battery at 0 (`/battery` refills) → "Camera battery empty! Find a battery 🔋", error beep, no photo.
- [ ] `/event falsealarm`: photographing a decoy (wet floor sign, glitching arcade machine, bouncy ball, stacked chair) shows its funny decoy message; only the real anomaly pays.

## 4. Multiple players photographing one anomaly
Local server with 3 players, `/spawn FloatingCart`.
- [ ] All three players can capture the same anomaly; each gets their own card and reward.
- [ ] Only the first photographer sees "⚡ FIRST!" and gets the +25% bonus.
- [ ] When another player is in the frame, the card shows "👥 GROUP PHOTO x2" and the reward is higher.
- [ ] Every player sees a flash on the photographer's hand camera when someone shoots, and hears the shutter in 3D from that position (quieter behind walls).
- [ ] Epic+ captures post a server toast "📸 NAME captured ... (EPIC)"; Nightmare+ play the full-screen reveal once for everybody ("FOUND BY NAME").
- [ ] `/spawn SmilingPlayer`: the chosen player sees nothing unusual on themselves; the other players see a wide black smile + tilted head on that player and can photograph it. The chosen player cannot capture themselves.
- [ ] `/spawn OneBehindYou`: the chosen player sees "DO NOT TURN AROUND." + red vignette; others see the tall figure behind them and can photograph it; if the chosen player turns the camera to look, the figure is invisible to them only.

## 5. Fake Player anomaly
- [ ] `/spawn FakePlayer` spawns a copy of a real player's avatar in the Main Hall.
- [ ] Its name tag is subtly misspelled (e.g. "Kacper" → "Kapcer" or l ↔ I).
- [ ] It walks towards the nearest player while facing them (moonwalking), stops about 7 studs away and stares.
- [ ] Every few seconds its head twists almost all the way around, then snaps back.
- [ ] It can be photographed (Epic reward) and disappears after its lifetime with no leftover parts in `Workspace.ActiveAnomalies`.

## 6. Round transitions
- [ ] Lobby shows "NEXT ROUND 0:10" (Studio) / 0:25 (live) and the HOW TO PLAY board.
- [ ] At 0:00 all players are teleported into the mall, the "📸 THE DEAD MALL IS OPEN" banner appears, the first anomalies spawn within about 5 seconds, and shoppers start walking.
- [ ] A player who joins mid-round, or resets, is placed in the mall and can score.
- [ ] Timer turns red in the last 30 seconds.
- [ ] At round end: all anomalies fade out, events end, lights are restored, everybody is teleported to the Lobby, and the EVIDENCE REPORT shows several awards (Most Evidence, Rarest Discovery, Best Photo, Most Photos Taken, Most New Discoveries, Group Photographer) plus "YOUR ROUND" highlights.
- [ ] After the results the loop returns to the Lobby countdown.
- [ ] Dark Room: during the Lobby, walk to the DARK ROOM door and press the prompt → teleport inside; frames show your top 5 rarest discoveries; ◀ ▶ browses other players' rooms; EXIT returns to the Lobby. When a round starts you are pulled into the mall.
- [ ] Performance: Developer Console (F9) → Memory/Scripts: `Workspace.ActiveAnomalies` is empty after each round; no errors in the Output.

## 7. Data saving
(Requires a published place + "Enable Studio Access to API Services".)
- [ ] Earn Evidence, discover 2-3 anomalies, buy an upgrade, change a setting, stop the test, play again: everything is still there (Evidence, album, best stars, times photographed, upgrades, equipped camera, settings, photo roll).
- [ ] Leaderboard shows **Evidence** and **Found**.
- [ ] Without API access in Studio, Output shows "temporary profile" and the game still runs.
- [ ] Two servers: join server A, then join server B with the same account → B waits for A's session lock (up to ~24 s) and loads the latest data; nothing is overwritten.
- [ ] Shutting down the server (Stop) saves all players (BindToClose).

## 8. Game Passes
(Set real IDs in MonetizationConfig, or `StudioGrantAllPasses = true`.)
- [ ] **Fast Camera**: buying the pass unlocks and auto-equips FastCam (Camera Bag shows EQUIPPED ✓); cooldown drops to ~0.55 s; the hand camera turns red.
- [ ] **Extra Album Storage**: Photo Roll capacity shows 60.
- [ ] **Bigger Dark Room**: 10 frames show discoveries instead of 5 (+5 no longer "🔒 BIGGER DARK ROOM").
- [ ] **VIP Photographer**: gold "⭐ VIP PHOTOGRAPHER" name tag, gold `[⭐ VIP]` chat prefix, gold hand camera, gold frames and nameplate in your Dark Room. No change to anomaly odds.
- [ ] Buying a pass in-game applies it immediately (no rejoin) and shows a thank-you toast.
- [ ] Passes with `Id = 0` show "UNAVAILABLE" and never prompt.

## 9. Developer Products
- [ ] **Small / Medium Evidence Pack**: Evidence increases by 5,000 / 20,000 exactly once per purchase.
- [ ] Buying the same product twice grants it twice (two different PurchaseIds).
- [ ] Force a failure (e.g. temporarily make `SaveNow` return false): the grant is not repeated in the same server when Roblox retries the receipt; the receipt is confirmed once saving works.
- [ ] **Blackout Event** during a round: "🔦 NAME CAUSED A BLACKOUT" banner, mall lights off, a toast tells players to use their flashlight (slot 2), Glowing Eyes / Shadow Runner can spawn; resetting the breaker in the Security Office (or the event ending) restores the lights.
- [ ] Buying an event product in the Lobby queues it ("queued - it starts as soon as possible") and it starts early in the next round.

## 10. Paranormal Surge
- [ ] `/event surge` (or buy the product): "⚠️ PARANORMAL ACTIVITY IS RISING" banner, purple tint, event pill with countdown.
- [ ] Anomalies spawn roughly twice as often and more at once; Rare+ appear noticeably more often.
- [ ] Bought by a player: banner reads "👁️ NAME CAUSED A PARANORMAL SURGE" and every player in the server benefits.
- [ ] Surge ends on time; spawn rate and tint return to normal.
- [ ] Other events: `/event rare` shows "⚠️ SOMETHING RARE IS HERE." without revealing where; `/event falsealarm` creates several decoys and exactly one real anomaly.

## 11. Server security
Use an exploit-style test from the Studio command bar on the **client** (Test → "Clients and Servers", select a client, command bar):
- [ ] `game.ReplicatedStorage.Remotes.PhotoRequest:FireServer(CFrame.new(0,50,0))` far from your head → the server uses your head position instead; nothing is captured through walls.
- [ ] Firing PhotoRequest 50 times in a loop → at most one accepted shot per cooldown and 6 per 4 s window.
- [ ] `PhotoRequest:FireServer("hack")` / `nil` / NaN CFrame → ignored, no error spam.
- [ ] `ShopRequest:InvokeServer("BuyCamera", "FastCam")` with too little Evidence → `false, "Not enough Evidence"`; `"EquipCamera","NightCam"` → refused; unknown actions → refused.
- [ ] `SettingRequest:FireServer("Evidence", 999999)` → ignored (only whitelisted settings; volumes are clamped to 0-1).
- [ ] `EquipmentAction:FireServer("Toggle", "Thermal")` without owning it → ignored; toggling an item that is not in your hand → ignored; spamming Toggle/Focus → rate limited.
- [ ] `MovementMode:FireServer("Run")` while stunned, or with an unknown mode → ignored; WalkSpeed is only ever set by the server.
- [ ] `ShopRequest:InvokeServer("BuyEquipment", "NightVision")` with too little Evidence → refused.
- [ ] `DarkRoomRequest:InvokeServer("Enter")` during a round → refused.
- [ ] There is no remote that grants Evidence, anomalies, cameras or purchases directly. Evidence only changes through PhotoService captures, EconomyService purchases, ProcessReceipt and admin commands.
- [ ] Admin commands typed by a non-admin in a live server do nothing.

## 12. Equipment & batteries
`/round start`, then `/equipment` (Studio: unlocks everything) and `/battery` (refill).
- [ ] New players own Camera, Flashlight and EMF; Thermal (15,000), UV Light (12,000) and Night Vision (20,000) are bought in Camera Bag → EQUIPMENT and appear in the Roblox hotbar immediately.
- [ ] Items are real Tools: other players see you holding the camera / flashlight / EMF / thermal / UV light; Night Vision goggles appear on your head.
- [ ] Batteries drain while items are on (flashlight, UV, NV, thermal, EMF) and per photo (camera). Low battery (20%) plays a warning + toast; empty plays a power-down.
- [ ] Batteries spawn around the mall (glowing, "Take Battery" prompt) and inside some lockers/drawers; picking one up charges your emptiest item.
- [ ] Batteries and camera battery reset at the start of each round.

## 13. Camera sound design
- [ ] Aiming around with the camera held: when the distance in the centre of the frame changes a lot you hear a quiet focus "beep" then the lens motor "zzzt".
- [ ] `/spawn TheObserver` (or any dangerous anomaly: Danger ≥ 0.6) and aim at it within ~55 studs: "beep… beep… BEEEEP", static and a screen glitch (autofocus broken).
- [ ] Photo sequence: button click → CLICK + FLASH → flash recharge whine. Capture success chime; Rare or better plays the special capture sound.
- [ ] `/spawn ThePhotographer` and focus on it: it turns to stare. Shoot near it: it flashes back at you (white flash + static).
- [ ] Buy **Silent Shutter** (UPGRADES): anomalies that hunt by sound react less to your shots (noise 0.15 → 0.10 → 0.05).

## 14. Flashlight, EMF, Thermal, UV, Night Vision
- [ ] Flashlight: equip/unequip sounds, on/off clicks, a beam on the handle. Toggling it rapidly (3+ times in 3 s) counts as a malfunction noise.
- [ ] Near a dangerous anomaly the flashlight buzzes (3D loop, other players hear it too), flickers and can die ("CLICK… nothing") for a few seconds.
- [ ] Battery empty: bulb failure sound, light goes out, the button only clicks.
- [ ] EMF: beeps get faster level 1 → 5 as you approach an anomaly (LEDs light up); other players hear your EMF in 3D. Very dangerous anomalies distort the beeps. When the anomaly vanishes the beeping stops abruptly.
- [ ] Thermal: activation whirr + scan loop; pointing at a cold anomaly lowers the temperature readout, plays "heat detected" and a lock chirp when centred; very close danger shows `ERR`.
- [ ] UV Light: purple beam with ballast hum; glowing residue prints near anomalies are only visible inside your UV beam (not to others).
- [ ] Night Vision: "BEEP—WHIRR" power-on, green view with scanlines and a local light, faint hum; near danger it shows static and can lose signal.

## 15. Footsteps & movement noise
- [ ] Each surface sounds different: marble/tile (Main Hall, Bathrooms), carpet (Cinema, Arcade), metal (Storage Hallway), concrete (Parking Garage), water (puddles under the skylight and in the garage), wood (Food Court stage) and broken glass (Toy Store entrance). No two consecutive steps sound identical.
- [ ] Sneaking is almost silent, running is loud, jump landings thud; falling from high up gives a heavy landing.
- [ ] Other players' and shoppers' footsteps are heard in 3D; behind a wall they are muffled and quieter.
- [ ] Roblox's default running sound never plays (replaced by `RbxCharacterSounds`).

## 16. Doors & interactions
- [ ] Doors: **E** opens (away from you), hold **E** = "Close quietly", **F** = "Slam" (very loud, heard far away). Each door type (wood restrooms, metal staff/garage doors, security door) sounds different.
- [ ] The Security Office door is locked (rattle + deny buzz). The key is hidden in a locker or drawer each round; with it the door unlocks.
- [ ] Lockers/drawers open/close with sounds and can contain batteries or the key. Elevator button → ding (sometimes the doors crack open…).
- [ ] The payphone rings on its own; answering it gives a whispered zone hint. Radio: static + garbled voice + a hint. Security PC: CCTV count. Breaker: ends a Blackout.

## 17. Sound-reactive anomalies & deception
- [ ] `/spawn TheListener`: breathing loop, it hears running, slams, shutters, flashlight clicks, EMF and chat, but NOT a flashlight beam. Sneak past it → it stays calm. Run / slam a door → alert clicks, it hunts; if it reaches you: jumpscare (Jumpscare volume setting applies), short stun, battery drain.
- [ ] `/spawn LightCreature` (dark spots): shining a flashlight/UV beam on it burns it away (shriek); clicking a flashlight nearby makes it relocate.
- [ ] `/spawn Echo`: repeat the same sound 3 times (e.g. several photos) → it replays your sounds from somewhere else.
- [ ] `/spawn Mimic`: fake shutter, footsteps behind you, a door opening, EMF beeps, flashlight clicks, battery pickups that are identical to real ones.
- [ ] `/phantom Footsteps` / `Shutter` / `FlashlightClick` / `DoorOpen` / `EMFBeep` / `BatteryPickup` / `Knock`: each plays a deceptive sound near you.
- [ ] `/thunder`: lightning flash through the skylight, thunder; for ~2.5 s the Listener cannot hear you run (environmental masking 0.8). HVAC bursts mask noise locally.
- [ ] Near a dangerous anomaly the music and ambience fade out (the silence rule), then return.

## 18. Mix, 3D audio and settings
- [ ] Album → SETTINGS: Master, Music, Ambience, Equipment, Voice and Jumpscare volumes change in 10% steps and are saved.
- [ ] Each mall zone has its own reverb (bathrooms, garage, cinema...); lobby music, mall hum/rain in the Main Hall, ventilation in back corridors.
- [ ] Before uploading audio every sound still plays (built-in fallbacks). After uploading the 4 banks and pasting the ids into `SoundConfig.Banks`, every sound uses the original audio (see `docs/SOUND_DESIGN.md`).
