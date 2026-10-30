# Caught On Camera – vertical ad (9:16)

`CaughtOnCamera_Ad.mp4` – 1080×1920, 30 fps, ~43 s, made for TikTok / Reels / Shorts.

Scenes: security-camera hook → title → SPOT IT / SNAP IT (photo, stars, new discovery) →
gear (flashlight, EMF, thermal, UV, night vision) → anomaly cards from Common to ??? →
Ceiling Crawler jumpscare → Dead Mall locations → squad up with friends → the album → end card.

All sound comes from the game's own audio banks (`assets/audio`), plus synthesised booms and whooshes.

## Rebuild

```
node tools/render.mjs          # ad.html -> out/ad_silent.mp4 (Playwright + ffmpeg)
python3 tools/mix_audio.py     # soundtrack -> out/CaughtOnCamera_Ad.mp4
node tools/render.mjs --stills 3,9.5   # single frames for checking
```

Open `ad.html` in a browser for a real-time preview (click to restart).
Fonts: Anton and Special Elite (SIL Open Font License).
