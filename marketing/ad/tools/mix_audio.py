"""Builds the ad soundtrack from the game's own sounds plus a few synthesised hits.

    python3 tools/mix_audio.py      -> out/ad_audio.wav, then out/CaughtOnCamera_Ad.mp4

Cue times follow the scene timeline in ad.html.
"""
import re
import subprocess
import wave
from pathlib import Path

import numpy as np

AD = Path(__file__).resolve().parents[1]
REPO = AD.parents[1]
OUT = AD / "out"
SR = 48000
DUR = 42.87


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


# Sound name -> first region, read from the generated layout.
layout = (REPO / "src/ReplicatedStorage/Config/SoundBankLayout.lua").read_text()
REGIONS = {m[0]: (m[1], float(m[2]), float(m[3]))
           for m in re.findall(r'\["([\w.]+)"\] = \{ Bank = "(\w+)", Regions = \{ \{ ([\d.]+), ([\d.]+) \}', layout)}
banks = {b: decode(REPO / f"assets/audio/banks/{b}.ogg") for b in ("Equipment", "Player", "World", "Loops")}


def snd(name):
    bank, a, b = REGIONS[name]
    return banks[bank][int(a * SR):int(b * SR)]


mix = np.zeros(int(DUR * SR) + SR, dtype=np.float32)


def put(t, clip, gain=1.0):
    i = int(t * SR)
    clip = clip[: max(0, len(mix) - i)]
    mix[i:i + len(clip)] += clip * gain


def env(n, attack=0.005, release=None):
    e = np.ones(n, dtype=np.float32)
    a = max(1, int(attack * SR)); e[:a] = np.linspace(0, 1, a)
    if release:
        r = min(n, int(release * SR)); e[-r:] *= np.linspace(1, 0, r)
    return e


rng = np.random.default_rng(7)


def boom(length=1.2, f0=110, f1=38):
    n = int(length * SR); t = np.arange(n) / SR
    freq = f1 + (f0 - f1) * np.exp(-t * 9)
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 3.2)
    click = rng.standard_normal(n) * np.exp(-t * 60) * 0.5
    return np.tanh((body + click) * 1.6).astype(np.float32) * 0.9


def whoosh(length=0.45, rising=True):
    n = int(length * SR)
    x = rng.standard_normal(n).astype(np.float32)
    # one-pole low-pass with a sweeping cutoff
    cut = np.linspace(0.02, 0.35, n) if rising else np.linspace(0.35, 0.02, n)
    y = np.zeros(n, dtype=np.float32); acc = 0.0
    for i in range(n):
        acc += cut[i] * (x[i] - acc); y[i] = acc
    shape = np.sin(np.linspace(0, np.pi, n)) ** 2
    return y * shape * 1.4


def riser(length):
    n = int(length * SR); t = np.arange(n) / SR
    f = 200 * (8 ** (t / length))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.25 + np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * 0.12
    noise = whoosh(length, True) * 0.8
    return ((tone + noise) * (t / length) ** 2).astype(np.float32)


def loop(clip, length):
    reps = int(np.ceil(length * SR / len(clip)))
    return np.tile(clip, reps)[: int(length * SR)]


# ---- beds ----
hum = loop(decode(REPO / "assets/audio/loops/MallHum.ogg"), 3.2) * env(int(3.2 * SR), 0.3, 0.3)
put(0, hum, 0.55)
put(0, loop(decode(REPO / "assets/audio/loops/HVAC.ogg"), 3.0) * env(int(3.0 * SR), 0.2, 0.2), 0.35)
music = decode(REPO / "assets/audio/loops/MusicTension.ogg")
m = loop(music, DUR - 3.0)
duck = np.ones(len(m), dtype=np.float32)
js0, js1 = int((25.38 - 3.0) * SR), int((28.6 - 3.0) * SR)
duck[js0:js1] = 0.12
fade = int(1.2 * SR); duck[js0 - fade:js0] = np.linspace(1, 0.12, fade); duck[js1:js1 + fade] = np.linspace(0.12, 1, fade)
duck[-int(1.5 * SR):] *= np.linspace(1, 0, int(1.5 * SR))
put(3.0, m * duck, 0.55)

# ---- 1. hook ----
for k, t in enumerate(np.arange(0.1, 1.3, 0.09)):
    put(t, snd("Camera.ButtonClick"), 0.25)
put(1.3, snd("Anomaly.Breath"), 0.6)
put(2.35, snd("Jumpscare.Static"), 0.8)
put(2.42, boom(0.8, 90, 40), 0.6)

# ---- 2. title ----
put(2.98, snd("Camera.Shutter"), 1.0)
put(3.0, snd("Camera.FlashTrigger"), 0.8)
put(3.0, boom(1.6), 1.0)
put(3.38, boom(1.0, 140, 50), 0.7)
put(3.75, snd("UI.Stinger"), 0.6)
put(4.85, whoosh(0.6, False), 0.4)

# ---- 3. spot it ----
put(5.6, whoosh(0.35), 0.5)
put(5.62, boom(0.6, 120, 60), 0.5)
put(6.7, snd("Anomaly.Sting"), 0.6)
for t in (6.95, 7.07, 7.19):
    put(t, snd("EMF.Level2"), 0.45)
put(7.35, snd("EMF.Level5"), 0.5)
put(7.4, snd("Camera.FlashCharge"), 0.5)

# ---- 4. snap it ----
put(8.82, snd("Camera.Shutter"), 1.0)
put(8.85, snd("Camera.FlashTrigger"), 0.9)
put(9.0, boom(1.0), 0.8)
put(9.0, snd("Camera.CaptureRare"), 0.7)
for i in range(5):
    put(9.7 + i * 0.12, snd("Camera.ButtonClick"), 0.6)
put(10.35, snd("UI.NewDiscovery"), 0.8)
put(11.15, whoosh(0.45), 0.7)

# ---- 5. gear ----
G = 11.6
put(G, boom(0.8), 0.7); put(G + 0.05, snd("Flashlight.On"), 0.9); put(G + 0.75, snd("Flashlight.Flicker"), 0.7)
put(G + 1.5, boom(0.7), 0.6); put(G + 1.5, snd("EMF.PowerOn"), 0.7)
for i, lvl in enumerate(range(1, 6)):
    put(G + 1.55 + i * 0.22, snd(f"EMF.Level{lvl}"), 0.6)
put(G + 2.45, snd("EMF.Distort"), 0.6)
put(G + 3.0, boom(0.7), 0.6); put(G + 3.0, decode(REPO / "assets/audio/loops/ThermalScan.ogg")[: int(1.5 * SR)] * env(int(1.5 * SR), 0.02, 0.2), 0.6)
put(G + 4.5, boom(0.7), 0.6); put(G + 4.5, loop(decode(REPO / "assets/audio/loops/UVHum.ogg"), 1.5) * env(int(1.5 * SR), 0.02, 0.2), 0.6)
put(G + 6.0, boom(0.7), 0.6); put(G + 6.0, loop(decode(REPO / "assets/audio/loops/NightVisionHum.ogg"), 1.5) * env(int(1.5 * SR), 0.02, 0.2), 0.6)
put(G + 6.3, snd("Anomaly.Breath"), 0.5)

# ---- 6. anomaly cards ----
C = 19.1
put(C, boom(1.4, 120, 35), 1.0)
put(C, snd("Anomaly.Sting"), 0.5)
for i in range(9):
    t = C + 0.7 + i * 0.62
    put(t - 0.12, whoosh(0.18), 0.5)
    put(t, boom(0.5, 130 + i * 8, 50), 0.45 + i * 0.05)
    if i >= 6:
        put(t, snd("Jumpscare.Static"), 0.5)
put(C + 0.7 + 6 * 0.62, snd("Anomaly.PhotographerFlash"), 0.6)

# ---- 7. don't look up ----
J = 25.38
put(J + 0.3, snd("Anomaly.CeilingCreak"), 0.8)
put(J + 0.7, snd("Anomaly.CeilingScuttle"), 0.9)
put(J + 1.0, riser(1.1), 0.8)
put(J + 1.6, snd("Anomaly.CeilingScuttle"), 0.9)
mix[int((J + 2.1) * SR):int((J + 2.2) * SR)] *= np.linspace(1, 0, int(0.1 * SR))
put(J + 2.2, snd("Jumpscare.CrawlerScreech"), 1.1)
put(J + 2.2, snd("Jumpscare.Impact"), 1.0)
put(J + 2.2, boom(1.6, 160, 30), 1.0)

# ---- 8. dead mall ----
E = 28.58
put(E, boom(1.0), 0.8)
put(E, snd("Environment.Thunder")[: int(2.5 * SR)], 0.5)
for i in range(6):
    put(E + 0.6 + i * 0.55 - 0.08, whoosh(0.15), 0.45)
    put(E + 0.6 + i * 0.55, boom(0.4, 150, 70), 0.35)
put(E + 0.6 + 2 * 0.55, snd("Anomaly.ArcadeJingle"), 0.4)

# ---- 9. squad ----
S = 32.48
put(S, boom(0.9), 0.7)
for a in range(6):
    put(S + 0.1 + a * 0.08, snd("Flashlight.On"), 0.35)
put(S + 1.38, snd("Camera.Shutter"), 1.0); put(S + 1.4, snd("Camera.FlashTrigger"), 0.7)
put(S + 1.45, snd("Camera.CaptureSuccess"), 0.7)
put(S + 2.1, snd("Camera.CaptureSuccess"), 0.5)
put(S + 2.8, whoosh(0.45), 0.7)

# ---- 10. album ----
A = 35.68
for n in range(16):
    put(A + 0.17 + n * 0.07, snd("Camera.ButtonClick"), 0.4)
put(A + 1.6, snd("UI.Reveal"), 0.8)
put(A + 1.6, boom(1.2), 0.8)

# ---- 11. end card ----
N = 38.68
put(N, boom(1.8, 120, 30), 1.0)
put(N, snd("UI.Stinger"), 0.7)
put(N + 0.9, snd("Camera.FlashCharge"), 0.4)
put(N + 3.72, snd("Camera.Shutter"), 1.0)
put(N + 3.75, snd("Camera.FlashTrigger"), 0.8)

# ---- master ----
mix = mix[: int(DUR * SR)]
mix /= max(1e-6, np.percentile(np.abs(mix), 99.9)) / 0.8
mix = np.tanh(mix * 1.1) * 0.9
pcm = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
OUT.mkdir(exist_ok=True)
with wave.open(str(OUT / "ad_audio.wav"), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())

subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(OUT / "ad_silent.mp4"), "-i", str(OUT / "ad_audio.wav"),
                "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-shortest", "-movflags", "+faststart",
                str(OUT / "CaughtOnCamera_Ad.mp4")], check=True)
print("wrote", OUT / "CaughtOnCamera_Ad.mp4")
