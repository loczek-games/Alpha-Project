"""
World sounds: anomalies, environment, UI, ambience beds and music loops.
"""

import numpy as np

from dsp import (
    Mix, T, N, beep, bell, bump, chime, crackle, creak, echo, env_perc, env_pts, fftconv, filt,
    fold, gate, glide, hz, modes, musicbox, noise_hit, pink, brown, pk, qf, reverb, ringmod,
    saturate, saw, sine, smooth, softsq, sparkle, sweep, thump, tick, tri, voice, white, whisper,
    zeros, repitch, formant_filter,
)

RECIPES = {}
LOOPS = {}


def reg(path, variations=1):
    def wrap(fn):
        RECIPES[path] = (fn, variations)
        return fn
    return wrap


def loop(name, length):
    def wrap(fn):
        LOOPS[name] = (fn, length)
        return fn
    return wrap


def cluster(freqs, d, shape="saw", lp=None):
    y = zeros(d)
    for f in freqs:
        y += saw(f, d, 40) if shape == "saw" else sine(f, d)
    return filt(y, None, lp) if lp else y


def screech(rng, d, base=2400, spread=(1.0, 1.06, 1.41)):
    t = T(d)
    y = zeros(d)
    for s in spread:
        f = base * s * (1 + 0.02 * np.sin(2 * np.pi * rng.uniform(5, 9) * t))
        y += sine(f, d) + 0.3 * sine(f * 2.01, d)
    return pk(y)


# ---------------------------------------------------------------------------
# ANOMALIES
# ---------------------------------------------------------------------------

@reg("Anomaly.Sting")
def sting(rng, v):
    d = 1.8
    low = cluster([55, 58.27, 82.41], d, "saw", 800) * env_pts(d, [(0, 0), (0.3, 1), (d, 0)])
    high = screech(rng, d, 2800, (1.0, 1.057)) * env_pts(d, [(0, 0), (0.35, 0.6), (d, 0)])
    rise = filt(white(0.35, rng), 1500, 10000) * env_pts(0.35, [(0, 0), (0.35, 1)])
    m = Mix().add(pk(low), 0, 0.8).add(high, 0, 0.35).add(pk(rise), 0, 0.3)
    m.add(thump(rng, 50, 0.2, 1.0), 0.33, 0.7)
    return reverb(m.render(), rng, rt=1.5, wet=0.3)


@reg("Anomaly.Vanish")
def vanish(rng, v):
    d = 0.8
    band = filt(white(d, rng), 500, 6000) * env_pts(d, [(0, 0), (d - 0.05, 1), (d, 0)])
    glass = sine(sweep(2200, 3300, d), d) * env_pts(d, [(0, 0), (d * 0.8, 0.4), (d, 0)])
    return reverb(pk(pk(band) + 0.3 * glass), rng, rt=0.9, wet=0.3)


@reg("Anomaly.ClockTick", 2)
def clock_tick(rng, v):
    f = 2400 if v == 0 else 2100
    return tick(rng, [f, f * 1.62], [0.012, 0.007], click=0.6)


@reg("Anomaly.DoorCreak", 2)
def anomaly_creak(rng, v):
    return creak(rng, rng.uniform(1.4, 1.8), (8, 30), ((330, 0.018), (760, 0.012), (1500, 0.006)), wobble=1.2)


@reg("Anomaly.Whisper", 3)
def anomaly_whisper(rng, v):
    return whisper(rng, rng.uniform(1.2, 1.6), rng.integers(4, 7), rng.uniform(0.9, 1.15))


@reg("Anomaly.Scratch", 2)
def scratch(rng, v):
    m = Mix()
    at = 0.0
    for _ in range(3):
        d = rng.uniform(0.18, 0.26)
        t = T(d)
        stick = 0.3 + 0.7 * (np.sin(2 * np.pi * rng.uniform(40, 90) * t) > 0)
        y = filt(white(d, rng), 1500, 7000) * stick * env_pts(d, [(0, 0), (0.03, 1), (d, 0.2)])
        m.add(pk(y), at, rng.uniform(0.6, 1))
        at += d + rng.uniform(0.03, 0.08)
    return m.render()


@reg("Anomaly.Knock", 3)
def knock(rng, v):
    j = 1 + rng.uniform(-0.06, 0.06)
    return tick(rng, [165 * j, 380 * j, 760 * j], [0.07, 0.05, 0.03], [1, 0.6, 0.3], click=0.5, lo=300, hi=4000)


@reg("Anomaly.Skitter", 2)
def skitter(rng, v):
    d = 0.6
    m = Mix()
    count = rng.integers(14, 23)
    for i in range(count):
        at = d * (i / count) + rng.uniform(-0.01, 0.01)
        f = rng.uniform(2000, 5000)
        m.add(tick(rng, [f], [rng.uniform(0.004, 0.01)], click=0.7), max(0, at), rng.uniform(0.3, 1.0))
    m.add(filt(white(d, rng), 2000, 6000) * gate(d, 0.05, 0.1), 0, 0.08)
    return m.render()


@reg("Anomaly.Groan", 2)
def groan(rng, v):
    d = 2.0
    t = T(d)
    f0 = 78 - 8 * t / d + 2 * np.sin(2 * np.pi * 4 * t)
    y = voice(rng, d, f0, [(0, "o"), (0.9, "u"), (1.6, "a")], breath=0.3, scale=0.85)
    y = saturate(filt(y, None, 3000), 1.5) * env_pts(d, [(0, 0), (0.3, 1), (1.5, 0.8), (d, 0)])
    return reverb(y, rng, rt=1.0, wet=0.2)


@reg("Anomaly.ObserverDrone")
def observer_drone(rng, v):
    d = 4.5
    t = T(d)
    y = sine(41.2, d) + sine(43.65, d) + 0.6 * sine(82.4, d) + 0.5 * sine(27.5, d)
    air = filt(brown(d, rng), 30, 400) * 0.5
    eerie = sine(1318.5 * (1 + 0.003 * np.sin(2 * np.pi * 0.7 * t)), d) * 0.05
    env = env_pts(d, [(0, 0), (1.2, 1), (3.3, 0.9), (d, 0)])
    return pk(pk(y + air) + eerie) * env


@reg("Anomaly.NightManagerChime")
def night_manager_chime(rng, v):
    d = 2.6
    detune = 2 ** (-15 / 1200)
    m = Mix()
    for i, midi in enumerate([79, 76, 72]):
        m.add(bell(rng, hz(midi) * detune, 1.4, partials=(1, 2.0, 3.0, 4.2), decays=[0.9, 0.5, 0.3, 0.15], amps=(1, 0.4, 0.25, 0.1)), i * 0.45, 1)
    y = m.render(d)
    wow = 0.004 * np.sin(2 * np.pi * 0.6 * T(d))
    idx = np.clip(np.arange(len(y)) * (1 + wow), 0, len(y) - 1)
    y = np.interp(idx, np.arange(len(y)), y)
    y = filt(y, 250, 5000) + 0.05 * pk(crackle(rng, d, 100, 800, 5000))
    return reverb(y, rng, rt=1.8, wet=0.35)


@reg("Anomaly.PhotographerFlash")
def photographer_flash(rng, v):
    m = Mix()
    m.add(noise_hit(rng, 0.3, 100, 12000, 0.012), 0, 1)
    m.add(thump(rng, 90, 0.04, 0.3), 0, 0.7)
    fizz = filt(white(0.4, rng), 3000, 12000) * env_perc(0.4, 0.002, 0.12)
    m.add(fizz, 0.005, 0.4)
    m.add(tick(rng, [1400, 2600, 4200], [0.02, 0.012, 0.006], click=0.8), 0.12, 0.5)
    d = 0.5
    m.add(sine(sweep(1500, 5000, d), d) * env_pts(d, [(0, 0), (0.1, 0.5), (d, 0)]), 0.3, 0.25)
    return reverb(m.render(), rng, rt=0.6, wet=0.2)


@loop("ListenerBreath", 4.0)
def listener_breath(rng, L):
    m = Mix()
    d_in = 1.5
    src = white(d_in, rng)
    breath_in = formant_filter(src, [(0, "o"), (d_in, "u")], 1.1, 2.5, 0.08)
    breath_in = filt(breath_in, 600, 9000) * env_pts(d_in, [(0, 0), (1.0, 1), (d_in, 0)])
    m.add(pk(breath_in), 0.1, 0.55)
    d_out = 1.8
    t = T(d_out)
    rasp = 0.55 + 0.45 * np.sin(2 * np.pi * rng.uniform(32, 42) * t)
    breath_out = formant_filter(white(d_out, rng), [(0, "a"), (d_out, "o")], 0.9, 2.0, 0.08)
    breath_out = filt(breath_out, 150, 6000) * rasp * env_pts(d_out, [(0, 0), (0.25, 1), (d_out, 0)])
    m.add(pk(breath_out), 1.75, 0.8)
    for _ in range(5):
        m.add(tick(rng, [rng.uniform(1500, 3500)], [0.004], click=0.8), rng.uniform(1.8, 3.2), rng.uniform(0.05, 0.15))
    return fold(m.render(L + 0.5), L)


@reg("Anomaly.ListenerAlert")
def listener_alert(rng, v):
    m = Mix()
    at = 0.0
    gap = 0.09
    for _ in range(10):
        m.add(tick(rng, [1800, 3200], [0.004, 0.003], click=0.9, lo=800), at, 0.8)
        at += gap
        gap *= 0.85
    d = 0.35
    gasp = formant_filter(white(d, rng), [(0, "i"), (d, "e")], 1.2, 2.5, 0.1)
    m.add(pk(filt(gasp, 1000, 9000) * env_pts(d, [(0, 0), (d * 0.8, 1), (d, 0)])), at + 0.05, 0.9)
    return reverb(m.render(), rng, rt=0.8, wet=0.25)


@reg("Anomaly.ListenerAttack")
def listener_attack(rng, v):
    d = 1.3
    t = T(d)
    f0 = glide([(0, 420), (0.3, 650), (d, 380)], d) * (1 + 0.05 * np.sin(2 * np.pi * 11 * t))
    scream = voice(rng, d, f0, [(0, "a"), (0.6, "e"), (d, "a")], breath=0.5)
    scream = saturate(scream, 4) * env_pts(d, [(0, 0), (0.04, 1), (1.0, 0.8), (d, 0)])
    m = Mix().add(scream, 0, 0.9)
    m.add(thump(rng, 55, 0.2, 0.8, 0.8), 0, 1.0)
    m.add(noise_hit(rng, 0.4, 100, 10000, 0.05), 0, 0.7)
    m.add(screech(rng, d, 2400) * env_pts(d, [(0, 0), (0.05, 1), (d, 0)]), 0, 0.3)
    return saturate(m.render(), 1.5)


@reg("Anomaly.LightCreatureHiss", 2)
def light_hiss(rng, v):
    d = 1.1
    t = T(d)
    rattle = 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(20, 30) * t)
    hiss = filt(white(d, rng), 3000, 11000) * rattle
    growl = filt(saw(90 + 10 * smooth(d, 6, rng), d, 30), None, 900)
    env = env_pts(d, [(0, 0), (0.15, 1), (0.7, 0.8), (d, 0)])
    return pk(pk(hiss) + 0.35 * pk(growl)) * env


@reg("Anomaly.LightCreatureShriek")
def light_shriek(rng, v):
    d = 1.5
    t = T(d)
    f0 = glide([(0, 900), (0.4, 1400), (d, 600)], d) * (1 + 0.04 * np.sin(2 * np.pi * 13 * t))
    y = voice(rng, d, f0, [(0, "i"), (0.8, "e"), (d, "e")], breath=0.4, scale=1.4)
    sizzle = crackle(rng, d, 900, 2500, 12000) * env_pts(d, [(0, 0.2), (d, 1)])
    y = saturate(pk(y) + 0.6 * pk(sizzle), 2.5) * env_pts(d, [(0, 0), (0.05, 1), (1.1, 0.8), (d, 0)])
    return reverb(y, rng, rt=0.9, wet=0.25)


@reg("Anomaly.EchoWhisper", 2)
def echo_whisper(rng, v):
    w = whisper(rng, 1.2, 5)
    return echo(w, [(0.28, 0.55), (0.56, 0.35), (0.84, 0.22), (1.12, 0.12)], lp=5000)


@reg("Anomaly.EchoVoice", 2)
def echo_voice(rng, v):
    m = Mix()
    m.add(voice(rng, 0.22, glide([(0, 180), (0.22, 190)], 0.22), [(0, "e"), (0.22, "e")], 0.3) * gate(0.22, 0.02, 0.05), 0, 1)
    m.add(voice(rng, 0.38, glide([(0, 170), (0.38, 215)], 0.38), [(0, "e"), (0.1, "o"), (0.38, "u")], 0.3) * gate(0.38, 0.02, 0.1), 0.26, 1)
    y = repitch(m.render(), 0.85)
    y = echo(y, [(0.18, 0.5), (0.36, 0.3), (0.54, 0.18)], lp=4000)
    return reverb(y, rng, rt=1.2, wet=0.35)


@reg("Anomaly.MimicGiggle", 2)
def mimic_giggle(rng, v):
    m = Mix()
    at = 0.0
    for i in range(rng.integers(5, 7)):
        d = rng.uniform(0.08, 0.11)
        f = rng.uniform(300, 420) * (1 - i * 0.02)
        y = voice(rng, d, glide([(0, f * 1.1), (d, f)], d), [(0, "e"), (d, "i")], 0.35, 1.15)
        m.add(y * gate(d, 0.01, 0.03), at, rng.uniform(0.6, 1))
        at += d + rng.uniform(0.04, 0.06)
    y = ringmod(m.render(), 60, 0.3)
    return reverb(y, rng, rt=0.7, wet=0.2)


@reg("Anomaly.Jumpscare")
def jumpscare(rng, v):
    d = 1.4
    m = Mix()
    m.add(thump(rng, 45, 0.3, d, 0.8), 0, 1)
    m.add(noise_hit(rng, 0.5, 80, 10000, 0.06), 0, 0.8)
    t = T(d)
    s = zeros(d)
    for f in (1500, 1590, 2240):
        s += saw(f * (1 + 0.05 * np.sin(2 * np.pi * 17 * t)), d, 8)
    m.add(pk(s) * env_pts(d, [(0, 0), (0.03, 1), (d, 0)]), 0, 0.45)
    return saturate(m.render(), 1.8)


# ---------------------------------------------------------------------------
# ENVIRONMENT
# ---------------------------------------------------------------------------

@reg("Environment.Thunder", 2)
def thunder(rng, v):
    d = 6.0
    t = T(d)
    env = np.exp(-0.5 * ((t - 0.2) / 0.15) ** 2)
    for _ in range(rng.integers(3, 6)):
        env += rng.uniform(0.3, 0.9) * np.exp(-0.5 * ((t - rng.uniform(0.5, 4.5)) / rng.uniform(0.3, 0.9)) ** 2)
    rumble = filt(brown(d, rng), 20, 400) * env
    sub = sine(38 + 6 * smooth(d, 1, rng), d) * env * 0.5
    y = pk(rumble) + 0.4 * pk(sub) + 0.15 * pk(crackle(rng, d, 60, 300, 3000) * env)
    return reverb(y * gate(d, 0.02, 1.0), rng, rt=2.0, wet=0.25, hi=2000)


@reg("Environment.LightningCrack")
def lightning_crack(rng, v):
    d = 1.2
    m = Mix().add(noise_hit(rng, 0.4, 200, 14000, 0.05), 0, 1)
    c = crackle(rng, 0.25, 2500, 1000, 12000) * env_perc(0.25, 0.001, 0.1)
    m.add(pk(c), 0, 0.7)
    rumble = filt(brown(d, rng), 30, 600) * env_perc(d, 0.05, 0.35)
    m.add(pk(rumble), 0.05, 0.5)
    return saturate(m.render(), 1.5)


@reg("Environment.HVACBurst")
def hvac_burst(rng, v):
    d = 3.5
    m = Mix().add(tick(rng, [85, 190, 400], [0.1, 0.06, 0.03], click=0.6, lo=100, hi=3000), 0, 0.8)
    roar = filt(pink(d, rng), 80, 2500) * env_pts(d, [(0, 0), (0.3, 1), (2.6, 0.9), (d, 0)])
    m.add(pk(roar), 0.05, 0.7)
    t = T(2.0)
    rattle = filt(white(2.0, rng), 500, 2500) * (np.sin(2 * np.pi * 18 * t) > 0.5) * env_pts(2.0, [(0, 0), (0.4, 1), (2.0, 0)])
    m.add(pk(rattle), 0.4, 0.2)
    return m.render()


@reg("Environment.DistantBang", 2)
def distant_bang(rng, v):
    d = 1.0
    y = pk(filt(brown(d, rng), 20, 250) * env_perc(d, 0.003, 0.35)) + 0.6 * sine(50, d) * env_perc(d, 0.003, 0.3)
    return reverb(pk(y), rng, rt=1.8, wet=0.5, hi=1500)


@reg("Environment.Drip", 3)
def drip(rng, v):
    dd = 0.06
    f0 = rng.uniform(450, 650)
    y = sine(sweep(f0, f0 * rng.uniform(2.2, 3.0), dd), dd) * env_perc(dd, 0.001, 0.02)
    m = Mix().add(y, 0, 1).add(tick(rng, [3000], [0.003], click=0.5), 0, 0.15)
    return reverb(m.render(), rng, rt=0.9, wet=0.2)


@reg("Environment.PAStatic")
def pa_static(rng, v):
    d = 1.6
    m = Mix().add(noise_hit(rng, 0.1, 80, 3000, 0.01), 0, 0.8)
    hum = (sine(60, d) + 0.5 * sine(120, d) + 0.25 * sine(180, d)) * gate(d, 0.05, 0.1)
    s = filt(white(d, rng), 400, 4000) * (0.4 + 0.6 * smooth(d, 14, rng)) + crackle(rng, d, 200, 800, 5000)
    m.add(pk(hum), 0.02, 0.4).add(pk(s) * gate(d, 0.05, 0.1), 0.02, 0.5)
    m.add(noise_hit(rng, 0.1, 80, 3000, 0.01), d, 0.6)
    return m.render()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

@reg("UI.Button")
def ui_button(rng, v):
    d = 0.06
    y = sine(sweep(900, 600, d), d) * env_perc(d, 0.001, 0.015)
    return Mix().add(y, 0, 1).add(tick(rng, [4500], [0.003], click=0.6), 0, 0.2).render()


@reg("UI.Toast")
def ui_toast(rng, v):
    return Mix().add(beep(hz(88), 0.04, "sine"), 0, 1).add(beep(hz(93), 0.05, "sine"), 0.05, 0.9).render()


@reg("UI.Announce")
def ui_announce(rng, v):
    return chime(rng, [hz(81), hz(88)], 0.14, 0.7, "bell")


@reg("UI.Reveal")
def ui_reveal(rng, v):
    d = 3.0
    m = Mix()
    m.add(thump(rng, 40, 0.8, d, 0.6), 0, 1)
    t = T(d)
    rise = zeros(d)
    for i in range(6):
        f = sweep(523.25 * (1 + i * 0.5), 1046.5 * (1 + i * 0.5), d)
        rise += sine(f * (1 + rng.uniform(-0.004, 0.004)), d) / (1 + i)
    rise *= env_pts(d, [(0, 0), (0.3, 0.1), (2.4, 1), (d, 0)])
    m.add(pk(rise), 0, 0.35)
    m.add(sparkle(rng, 2.5, 30), 0.5, 0.25)
    return reverb(m.render(), rng, rt=2.2, wet=0.35)


@reg("UI.NewDiscovery")
def ui_new_discovery(rng, v):
    m = Mix().add(chime(rng, [hz(84), hz(88), hz(91), hz(96), hz(100)], 0.06, 0.9, "bell"), 0, 1)
    m.add(sparkle(rng, 1.0, 14), 0.2, 0.3)
    d = 0.4
    m.add(filt(white(d, rng), 2000, 9000) * env_pts(d, [(0, 0), (0.2, 1), (d, 0)]), 0, 0.1)
    return reverb(m.render(), rng, rt=1.0, wet=0.25)


@reg("UI.Fail")
def ui_fail(rng, v):
    d = 0.3
    return sine(sweep(300, 180, d), d) * env_perc(d, 0.003, 0.1)


@reg("UI.Whisper", 2)
def ui_whisper(rng, v):
    return whisper(rng, 1.0, 4)


@reg("UI.Heartbeat")
def ui_heartbeat(rng, v):
    m = Mix().add(thump(rng, 55, 0.08, 0.4, 0.2), 0, 1).add(thump(rng, 65, 0.07, 0.4, 0.2), 0.28, 0.75)
    return filt(m.render(), None, 400)


@reg("UI.Error")
def ui_error(rng, v):
    b = filt(softsq(200, 0.1, 4), None, 2500) * gate(0.1, 0.003, 0.01)
    return Mix().add(b, 0, 1).add(b, 0.14, 1).render()


@reg("UI.Stinger")
def ui_stinger(rng, v):
    d = 1.6
    m = Mix().add(thump(rng, 48, 0.3, d, 0.6), 0, 1)
    m.add(pk(cluster([61.7, 65.4, 92.5], d, "saw", 700)) * env_perc(d, 0.01, 0.5), 0, 0.6)
    m.add(screech(rng, 0.9, 2200, (1.0, 1.06)) * env_pts(0.9, [(0, 0), (0.6, 1), (0.9, 0)]), 0.1, 0.25)
    return reverb(m.render(), rng, rt=1.4, wet=0.3)


# ---------------------------------------------------------------------------
# AMBIENCE LOOPS (perfectly periodic: circular filters, whole-cycle tones)
# ---------------------------------------------------------------------------

@loop("MallHum", 20.0)
def mall_hum(rng, L):
    t = T(L)
    hum = softsq(qf(120, L), L, 2.0) + 0.5 * sine(qf(60, L), L) + 0.2 * sine(qf(240, L), L)
    hum = filt(hum, None, 2000, circular=True)
    room = filt(brown(L, rng, circular=True), 20, 300, circular=True)
    whine = sine(qf(10000, L), L) * 0.02
    drift = 0.85 + 0.1 * np.sin(2 * np.pi * qf(0.1, L) * t) + 0.05 * np.sin(2 * np.pi * qf(0.35, L) * t)
    return (0.35 * pk(hum) * drift + 0.6 * pk(room) + whine)


@loop("RainSkylight", 20.0)
def rain_skylight(rng, L):
    t = T(L)
    wash = filt(pink(L, rng, circular=True), 500, 9000, circular=True)
    n = N(L)
    drops = (rng.random(n) < 60 / 44100) * rng.uniform(0.2, 1.0, n)
    drops = filt(drops, 2500, 11000, circular=True)
    heavy = (rng.random(n) < 5 / 44100) * rng.uniform(0.5, 1.0, n)
    heavy = peaks(heavy, [(1200, 250, 8), (2100, 300, 5)])
    drum = filt(brown(L, rng, circular=True), 30, 200, circular=True)
    swell = 0.8 + 0.2 * np.sin(2 * np.pi * qf(0.05, L) * t) + 0.08 * np.sin(2 * np.pi * qf(0.23, L) * t)
    return (pk(wash) * 0.5 + pk(drops) * 0.4 + pk(heavy) * 0.25 + pk(drum) * 0.3) * swell


def peaks(x, bands):
    from dsp import peaks as _peaks
    return _peaks(x, bands, 0.2, circular=True)


@loop("HVAC", 20.0)
def hvac_loop(rng, L):
    t = T(L)
    air = filt(pink(L, rng, circular=True), 60, 1500, circular=True)
    sub = sine(qf(30, L), L)
    blade = sine(qf(94.5, L), L)
    flutter = 0.9 + 0.1 * np.sin(2 * np.pi * qf(6, L) * t)
    return pk(air) * 0.7 * flutter + 0.25 * sub + 0.05 * blade


# ---------------------------------------------------------------------------
# MUSIC LOOPS (original compositions, rendered with a wrap-around tail)
# ---------------------------------------------------------------------------

BPM = 75
BEAT = 60 / BPM
BAR = BEAT * 4
MUSIC_LEN = BAR * 8  # 25.6 s


def pad_note(rng, f, d):
    y = tri(f * 2 ** (6 / 1200), d) + tri(f * 2 ** (-6 / 1200), d) + 0.3 * sine(f * 2, d)
    return filt(y, None, 1800) * env_pts(d, [(0, 0), (0.8, 1), (d - 1.2, 0.9), (d, 0)])


def tape_wow(x, L, depth=0.0015, rate=None):
    rate = rate or qf(0.3125, L)
    n = len(x)
    idx = np.arange(n) + depth * 44100 * np.sin(2 * np.pi * rate * np.arange(n) / 44100)
    return np.interp(np.clip(idx, 0, n - 1), np.arange(n), x)


@loop("MusicLobby", MUSIC_LEN)
def music_lobby(rng, L):
    # Am - F - Dm - E, two bars each: cosy, a little mysterious
    chords = [
        (57, [57, 60, 64], [69, 72, 76, 79, 81]),
        (53, [53, 57, 60], [69, 72, 77, 76, 72]),
        (50, [50, 53, 57], [69, 74, 77, 76, 74]),
        (52, [52, 56, 59], [68, 71, 76, 74, 71]),
    ]
    m = Mix()
    for ci, (root, triad, melody) in enumerate(chords):
        start = ci * BAR * 2
        for note in triad:
            m.add(pad_note(rng, hz(note), BAR * 2 + 1.5), start, 0.18)
        for b in (0, 2, 4, 6):
            dd = BEAT * 1.8
            bass = sine(hz(root - 12), dd) * env_perc(dd, 0.01, 0.6)
            m.add(bass, start + b * BEAT, 0.35)
        # music box: sparse eighth-note figure, seeded variation
        for k in range(16):
            if rng.random() < (0.55 if k % 2 == 0 else 0.25):
                note = melody[rng.integers(0, len(melody))]
                m.add(musicbox(rng, hz(note)), start + k * BEAT / 2, rng.uniform(0.18, 0.28))
    y = fold(m.render(L + 4.0), L)
    return tape_wow(y, L)


@loop("MusicTension", MUSIC_LEN)
def music_tension(rng, L):
    t = T(L)
    drone_f = qf(73.42, L)
    drone = filt(saw(drone_f, L, 30), None, 350, circular=True) + 0.6 * sine(qf(drone_f / 2, L), L)
    drone *= 0.8 + 0.2 * np.sin(2 * np.pi * qf(0.078, L) * t)
    strings = sine(qf(587.33, L), L) + sine(qf(622.25, L), L)
    strings *= (0.7 + 0.3 * np.sin(2 * np.pi * qf(5, L) * t)) * (0.5 - 0.5 * np.cos(2 * np.pi * qf(1 / 12.8, L) * t))
    m = Mix().add(pk(drone), 0, 0.5).add(pk(strings), 0, 0.12)
    beat = 1.6
    for i in range(int(round(L / beat))):
        m.add(thump(rng, 50, 0.07, 0.3, 0.2), i * beat, 0.45)
        m.add(thump(rng, 60, 0.06, 0.3, 0.2), i * beat + 0.28, 0.32)
    for i in range(int(round(L / (BEAT / 2)))):
        m.add(tick(rng, [5200, 7400], [0.004, 0.003], click=0.6), i * BEAT / 2, 0.05 if i % 2 else 0.08)
    phrygian = [74, 75, 77, 79, 81, 82, 84, 86]
    for _ in range(7):
        m.add(bell(rng, hz(phrygian[rng.integers(0, len(phrygian))]), 2.0, amps=(1, 0.3, 0.3, 0.1, 0.05)), rng.uniform(0, L), 0.12)
    return fold(m.render(L + 3.0), L)
