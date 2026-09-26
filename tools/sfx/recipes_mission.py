"""
Mission sounds: per-anomaly jumpscares, the ceiling crawler, object
anomalies, alarms, lobby queue UI, revive. All synthesised from scratch.
"""

import numpy as np

from dsp import (
    Mix, T, N, beep, chime, creak, env_perc, env_pts, filt, gate, glide, hz, noise_hit, pk, reverb,
    ringmod, rustle, saturate, saw, sine, smooth, softsq, sweep, thump, tick, voice, white, whisper,
    zeros, brown, pink, crush, qf, tri, fit,
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


def screech(rng, d, base, spread=(1.0, 1.06, 1.41), vib=(6, 11), depth=0.03):
    t = T(d)
    y = zeros(d)
    for s in spread:
        f = base * s * (1 + depth * np.sin(2 * np.pi * rng.uniform(*vib) * t))
        y += sine(f, d) + 0.35 * sine(f * 2.01, d) + 0.15 * sine(f * 3.02, d)
    return pk(y)


def chitter(rng, d, density=40, lo=1800, hi=5200):
    m = Mix()
    count = int(d * density)
    for i in range(count):
        at = d * i / max(count, 1) + rng.uniform(-0.004, 0.004)
        f = rng.uniform(lo, hi)
        m.add(tick(rng, [f, f * 1.7], [rng.uniform(0.003, 0.008), 0.003], click=0.8), max(0.0, at), rng.uniform(0.3, 1.0))
    return m.render()


# ---------------------------------------------------------------------------
# JUMPSCARES (every major anomaly has its own)
# ---------------------------------------------------------------------------

@reg("Jumpscare.Impact", 2)
def js_impact(rng, v):
    d = 1.2
    m = Mix()
    m.add(thump(rng, 38 + 6 * v, 0.35, d, 0.9), 0, 1)
    m.add(noise_hit(rng, 0.4, 60, 9000, 0.05), 0, 0.9)
    ring = zeros(d)
    for f in (410, 623, 1187):
        ring += sine(f * (1 + rng.uniform(-0.01, 0.01)), d) * env_perc(d, 0.001, 0.35)
    m.add(pk(ring), 0, 0.25)
    return saturate(m.render(), 2.2)


@reg("Jumpscare.Screech")
def js_screech(rng, v):
    d = 1.3
    s = screech(rng, d, 1900, (1.0, 1.059, 1.5), (9, 15), 0.05) * env_pts(d, [(0, 0), (0.02, 1), (0.8, 0.7), (d, 0)])
    grit = filt(white(d, rng), 1500, 8000) * env_pts(d, [(0, 0), (0.02, 1), (d, 0)])
    return saturate(pk(s) + 0.35 * pk(grit), 2.6)


@reg("Jumpscare.CrawlerDrop")
def js_crawler_drop(rng, v):
    d = 1.1
    m = Mix()
    # legs rattling as it lets go of the ceiling
    m.add(chitter(rng, 0.35, 70, 1200, 4200), 0, 0.8)
    # rush of air
    air = filt(white(0.4, rng), 300, 3000) * env_pts(0.4, [(0, 0), (0.3, 1), (0.4, 0.2)])
    m.add(pk(air), 0.2, 0.7)
    # landing right on you
    m.add(thump(rng, 44, 0.3, 0.7, 0.8), 0.45, 1)
    m.add(noise_hit(rng, 0.25, 80, 6000, 0.04), 0.45, 0.8)
    return saturate(m.render(), 1.8)


@reg("Jumpscare.CrawlerScreech")
def js_crawler_screech(rng, v):
    d = 1.4
    t = T(d)
    s = screech(rng, d, 2600, (1.0, 1.12, 1.33), (18, 30), 0.08)
    s = ringmod(s, 90, 0.6) * env_pts(d, [(0, 0), (0.02, 1), (1.0, 0.8), (d, 0)])
    clicks = fit(chitter(rng, d, 55, 2500, 7000), N(d)) * (0.4 + 0.6 * (t < 0.9))
    hiss = filt(white(d, rng), 3000, 9000) * env_pts(d, [(0, 0), (0.05, 1), (d, 0)])
    return saturate(pk(s) + 0.5 * pk(clicks) + 0.3 * pk(hiss), 2.0)


@reg("Jumpscare.Titan")
def js_titan(rng, v):
    d = 2.0
    t = T(d)
    f0 = 58 + 10 * np.exp(-t * 3) + 3 * np.sin(2 * np.pi * 7 * t)
    roar = voice(rng, d, f0, [(0, "a"), (0.6, "o"), (1.4, "u")], breath=0.6, scale=0.7)
    roar = saturate(filt(roar, None, 2600), 3.0) * env_pts(d, [(0, 0), (0.05, 1), (1.4, 0.8), (d, 0)])
    m = Mix().add(pk(roar), 0, 1).add(thump(rng, 32, 0.6, d, 0.5), 0, 0.8)
    return reverb(m.render(), rng, rt=1.6, wet=0.3)


@reg("Jumpscare.Smile")
def js_smile(rng, v):
    d = 1.6
    m = Mix()
    at = 0.0
    for i in range(6):
        seg = rng.uniform(0.09, 0.13)
        f = 520 * (1 - i * 0.06)
        y = voice(rng, seg, glide([(0, f * 1.2), (seg, f)], seg), [(0, "e"), (seg, "i")], 0.4, 1.25)
        m.add(y * gate(seg, 0.005, 0.03), at, 1)
        at += seg + 0.03
    laugh = ringmod(m.render(), 35, 0.35)
    hit = Mix().add(thump(rng, 50, 0.3, 0.8, 0.6), 0, 1).add(noise_hit(rng, 0.3, 200, 8000, 0.04), 0, 0.5).render()
    return saturate(Mix().add(pk(laugh), 0, 0.8).add(hit, 0.02, 1).render(), 1.6)


@reg("Jumpscare.Possessed")
def js_possessed(rng, v):
    d = 1.5
    t = T(d)
    f0 = 330 + 90 * np.sin(2 * np.pi * 3 * t) + 40 * smooth(d, 12, rng)
    scream = voice(rng, d, f0, [(0, "a"), (0.5, "e"), (1.1, "a")], breath=0.5, scale=1.1, jitter=0.05)
    scream = saturate(scream, 3.0) * env_pts(d, [(0, 0), (0.03, 1), (1.1, 0.7), (d, 0)])
    reverse = filt(white(0.5, rng), 400, 5000) * env_pts(0.5, [(0, 0), (0.48, 1), (0.5, 0)])
    return Mix().add(pk(reverse), 0, 0.4).add(pk(scream), 0.45, 1).render()


@reg("Jumpscare.Slacker")
def js_slacker(rng, v):
    d = 1.4
    stat = crush(filt(white(d, rng), 200, 9000), 4, 6) * env_pts(d, [(0, 0), (0.02, 1), (0.6, 0.6), (d, 0)])
    t = T(d)
    groan = voice(rng, d, 70 + 5 * np.sin(2 * np.pi * 5 * t), [(0, "o"), (1.0, "u")], 0.5, 0.8)
    return saturate(pk(stat) * 0.6 + pk(groan), 2.0)


@reg("Jumpscare.Static")
def js_static(rng, v):
    d = 0.9
    y = crush(filt(white(d, rng), 100, 10000), 5, 3)
    return pk(y) * env_pts(d, [(0, 0), (0.01, 1), (0.7, 0.8), (d, 0)])


@reg("Jumpscare.Ringing")
def js_ringing(rng, v):
    d = 3.0
    y = sine(3500, d) * 0.6 + sine(3512, d) * 0.4
    return y * env_pts(d, [(0, 0), (0.05, 0.8), (d, 0)])


@reg("Jumpscare.Fall")
def js_fall(rng, v):
    d = 0.9
    m = Mix()
    m.add(rustle(rng, 0.35, 400, 3000, 12, 0.3), 0, 0.5)
    m.add(thump(rng, 60, 0.18, 0.5, 0.6), 0.35, 1)
    m.add(noise_hit(rng, 0.2, 100, 2500, 0.03), 0.35, 0.5)
    return filt(m.render(), None, 3500)


# ---------------------------------------------------------------------------
# CEILING CRAWLER + creature movement
# ---------------------------------------------------------------------------

@reg("Anomaly.CeilingCreak", 2)
def ceiling_creak(rng, v):
    return creak(rng, rng.uniform(0.9, 1.4), (10, 22), ((180, 0.02), (410, 0.014), (900, 0.007)), wobble=1.8)


@reg("Anomaly.CeilingScuttle", 2)
def ceiling_scuttle(rng, v):
    d = 1.2
    m = Mix()
    steps = rng.integers(10, 16)
    for i in range(steps):
        at = d * i / steps + rng.uniform(-0.02, 0.02)
        m.add(tick(rng, [rng.uniform(300, 700), rng.uniform(1200, 2400)], [0.03, 0.01], click=0.5, lo=200, hi=5000), max(0.0, at), rng.uniform(0.5, 1))
    m.add(filt(brown(d, rng), 60, 500) * env_pts(d, [(0, 0), (0.2, 1), (d, 0)]), 0, 0.2)
    return filt(m.render(), None, 4000)


@reg("Anomaly.DustFall")
def dust_fall(rng, v):
    d = 1.4
    grains = Mix()
    for _ in range(40):
        grains.add(tick(rng, [rng.uniform(3000, 8000)], [0.002], click=0.9), rng.uniform(0, d - 0.05), rng.uniform(0.1, 0.4))
    hiss = filt(white(d, rng), 2000, 7000) * env_pts(d, [(0, 0), (0.1, 1), (d, 0)])
    return fit(pk(grains.render()), N(d)) * 0.6 + pk(hiss) * 0.3


@reg("Anomaly.Breath", 2)
def breath(rng, v):
    d = 1.3
    air = filt(white(d, rng), 300, 2400) * env_pts(d, [(0, 0), (0.5, 1), (0.8, 0.8), (d, 0)])
    rasp = filt(white(d, rng), 90, 400) * (0.5 + 0.5 * np.sin(2 * np.pi * 34 * T(d)) ** 2) * env_pts(d, [(0, 0), (0.6, 1), (d, 0)])
    return pk(air) + 0.4 * pk(rasp)


@reg("Anomaly.Snap", 2)
def snap(rng, v):
    return Mix().add(tick(rng, [900, 2100, 3400], [0.02, 0.012, 0.006], click=0.9, lo=400, hi=9000), 0, 1).add(tick(rng, [700, 1600], [0.015, 0.008], click=0.8), 0.04, 0.6).render()


@reg("Anomaly.Teleport")
def teleport(rng, v):
    d = 0.7
    rev = filt(white(d, rng), 400, 6000) * env_pts(d, [(0, 0), (0.6, 1), (0.62, 0), (d, 0)])
    zap = sine(sweep(1800, 90, 0.12), 0.12) * env_perc(0.12, 0.001, 0.05)
    return Mix().add(pk(rev), 0, 0.8).add(zap, 0.6, 0.8).render()


@reg("Anomaly.Laugh", 2)
def laugh(rng, v):
    m = Mix()
    at = 0.0
    for i in range(rng.integers(4, 7)):
        seg = rng.uniform(0.1, 0.15)
        f = rng.uniform(140, 180) * (1 - i * 0.03)
        y = voice(rng, seg, glide([(0, f * 1.15), (seg, f)], seg), [(0, "a"), (seg, "o")], 0.5, 0.9)
        m.add(y * gate(seg, 0.01, 0.04), at, rng.uniform(0.7, 1))
        at += seg + rng.uniform(0.05, 0.09)
    return reverb(m.render(), rng, rt=1.2, wet=0.35)


@reg("Anomaly.Thud", 2)
def thud(rng, v):
    return Mix().add(thump(rng, 52 + 8 * v, 0.2, 0.6, 0.5), 0, 1).add(noise_hit(rng, 0.15, 100, 2000, 0.02), 0, 0.4).render()


@reg("Anomaly.GlassTap", 3)
def glass_tap(rng, v):
    f = rng.uniform(2400, 3200)
    return tick(rng, [f, f * 1.51, f * 2.3], [0.03, 0.02, 0.01], [1, 0.5, 0.3], click=0.6, lo=1500, hi=12000)


# ---------------------------------------------------------------------------
# OBJECT ANOMALIES
# ---------------------------------------------------------------------------

@reg("Anomaly.CartRoll")
def cart_roll(rng, v):
    d = 2.0
    t = T(d)
    rattle = Mix()
    rate = 18
    for i in range(int(d * rate)):
        rattle.add(tick(rng, [rng.uniform(800, 1600), rng.uniform(2500, 4000)], [0.01, 0.005], click=0.5), i / rate + rng.uniform(0, 0.01), rng.uniform(0.3, 0.8))
    rumble = filt(brown(d, rng), 40, 300) * (0.8 + 0.2 * np.sin(2 * np.pi * 9 * t))
    squeak = sine(1900 + 200 * np.sin(2 * np.pi * 3 * t), d) * (np.sin(2 * np.pi * 1.5 * t) > 0.7) * 0.2
    return (fit(pk(rattle.render()), N(d)) * 0.6 + pk(rumble) * 0.5 + squeak) * env_pts(d, [(0, 0), (0.2, 1), (1.7, 1), (d, 0)])


@reg("Anomaly.ChairScrape", 2)
def chair_scrape(rng, v):
    d = rng.uniform(0.6, 0.9)
    t = T(d)
    stick = 0.4 + 0.6 * (np.sin(2 * np.pi * rng.uniform(70, 110) * t) > 0)
    y = filt(white(d, rng), 500, 4000) * stick
    tone = saw(rng.uniform(180, 260) * (1 + 0.1 * t), d, 20) * 0.2
    return pk(y + tone) * env_pts(d, [(0, 0), (0.05, 1), (d - 0.1, 0.8), (d, 0)])


@reg("Anomaly.ShelfCrash")
def shelf_crash(rng, v):
    d = 1.8
    m = Mix()
    m.add(thump(rng, 48, 0.4, d, 0.6), 0, 1)
    m.add(noise_hit(rng, 0.8, 200, 9000, 0.15), 0, 0.8)
    for _ in range(18):
        f = rng.uniform(600, 3500)
        m.add(tick(rng, [f, f * 1.4], [rng.uniform(0.02, 0.08), 0.02], click=0.5, lo=300, hi=8000), rng.uniform(0.05, 1.3), rng.uniform(0.2, 0.7))
    return saturate(m.render(), 1.4)


@reg("Anomaly.BallBounce", 3)
def ball_bounce(rng, v):
    f = rng.uniform(140, 200)
    return Mix().add(thump(rng, f, 0.06, 0.25, 0.15), 0, 1).add(sine(f * 2.2, 0.08) * env_perc(0.08, 0.001, 0.03), 0, 0.3).render()


@reg("Anomaly.BagRustle", 2)
def bag_rustle(rng, v):
    return rustle(rng, rng.uniform(0.6, 1.0), 900, 7000, 14, 0.7)


@reg("Anomaly.MetalGroan")
def metal_groan(rng, v):
    d = 2.6
    t = T(d)
    f = 95 + 30 * smooth(d, 1.5, rng)
    y = saw(f, d, 30) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t))
    y = filt(y, 60, 1400)
    return reverb(pk(y) * env_pts(d, [(0, 0), (0.6, 1), (2.0, 0.8), (d, 0)]), rng, rt=2.2, wet=0.4)


@reg("Anomaly.ArcadeJingle")
def arcade_jingle(rng, v):
    notes = [72, 76, 79, 84, 83, 79, 76, 71]
    m = Mix()
    at = 0.0
    for n in notes:
        f = hz(n) * (1 + rng.uniform(-0.015, 0.015))  # slightly out of tune
        m.add(beep(f, 0.12, "softsq", 6, 0.002, 0.02, 5000), at, 0.8)
        at += 0.13
    return crush(m.render(), 5, 3)


@reg("Anomaly.TVOn")
def tv_on(rng, v):
    d = 0.8
    pop = noise_hit(rng, 0.05, 200, 6000, 0.01)
    whine = sine(15700, d) * 0.15 * env_pts(d, [(0, 0), (0.1, 1), (d, 0.6)])
    stat = filt(white(d, rng), 500, 9000) * env_pts(d, [(0, 0), (0.05, 1), (d, 0.3)])
    return Mix().add(pop, 0, 1).add(pk(stat) * 0.5, 0.03, 1).add(whine, 0, 1).render()


# ---------------------------------------------------------------------------
# ENVIRONMENT / UI / INTERACTION
# ---------------------------------------------------------------------------

@reg("Environment.LightBuzz", 2)
def light_buzz(rng, v):
    d = 0.9
    t = T(d)
    hum = softsq(120, d, 4) * (0.5 + 0.5 * (np.sin(2 * np.pi * rng.uniform(8, 14) * t) > 0))
    ticks = Mix()
    for _ in range(6):
        ticks.add(tick(rng, [rng.uniform(2000, 5000)], [0.004], click=0.9), rng.uniform(0, d - 0.05), 0.5)
    return pk(filt(hum, None, 4000)) * 0.6 + fit(pk(ticks.render()), N(d)) * 0.4


@reg("Environment.PAChime")
def pa_chime(rng, v):
    return chime(rng, [hz(76), hz(72), hz(67)], 0.32, 1.1, "bell")


@reg("UI.QueueJoin")
def ui_queue_join(rng, v):
    return Mix().add(beep(hz(69), 0.06, "sine"), 0, 0.9).add(beep(hz(76), 0.09, "sine"), 0.07, 1).render()


@reg("UI.QueueLeave")
def ui_queue_leave(rng, v):
    return Mix().add(beep(hz(76), 0.06, "sine"), 0, 0.9).add(beep(hz(69), 0.09, "sine"), 0.07, 1).render()


@reg("UI.QueueTick")
def ui_queue_tick(rng, v):
    return tick(rng, [1800, 2700], [0.012, 0.006], click=0.4)


@reg("UI.QueueTickFinal")
def ui_queue_tick_final(rng, v):
    return beep(hz(81), 0.09, "softsq", 3, 0.002, 0.03, 6000)


@reg("UI.Terminal")
def ui_terminal(rng, v):
    m = Mix()
    for i in range(4):
        m.add(beep(rng.uniform(1200, 2400), 0.025, "softsq", 5, 0.001, 0.005, 7000), i * 0.035, 0.6)
    m.add(filt(white(0.15, rng), 3000, 9000) * env_perc(0.15, 0.002, 0.05), 0, 0.15)
    return m.render()


@reg("UI.MissionStart")
def ui_mission_start(rng, v):
    d = 2.2
    m = Mix()
    # tape machine starting + low boom
    t = T(0.6)
    motor = saw(40 + 80 * t / 0.6, 0.6, 20) * env_pts(0.6, [(0, 0), (0.5, 1), (0.6, 0)])
    m.add(filt(pk(motor), None, 800), 0, 0.5)
    m.add(thump(rng, 36, 0.8, 1.6, 0.4), 0.55, 1)
    m.add(filt(white(d, rng), 2000, 8000) * env_pts(d, [(0, 0), (0.6, 0.3), (d, 0)]), 0, 0.1)
    return reverb(m.render(), rng, rt=1.8, wet=0.3)


@reg("Interaction.Revive")
def revive(rng, v):
    d = 1.0
    gasp = filt(white(0.5, rng), 500, 3000) * env_pts(0.5, [(0, 0), (0.12, 1), (0.5, 0)])
    cloth = rustle(rng, 0.5, 400, 3000, 10, 0.3)
    return Mix().add(cloth, 0, 0.6).add(pk(gasp), 0.35, 0.8).render()


# ---------------------------------------------------------------------------
# LOOPS
# ---------------------------------------------------------------------------

@loop("CarAlarm", 4.0)
def car_alarm(rng, L):
    t = T(L)
    f = qf(900, L) + qf(450, L) * np.sin(2 * np.pi * qf(1.0, L) * t)
    y = softsq(f, L, 3)
    return filt(y, 300, 5000, circular=True) * 0.8


@loop("StoreAlarm", 3.0)
def store_alarm(rng, L):
    t = T(L)
    bell = zeros(L)
    rate = qf(18, L)
    strike = (np.sin(2 * np.pi * rate * t) > 0).astype(float)
    for f, a in ((qf(2100, L), 1.0), (qf(3350, L), 0.5), (qf(5200, L), 0.25)):
        bell += a * sine(f, L)
    return pk(bell * (0.4 + 0.6 * strike))


@loop("TVStatic", 4.0)
def tv_static(rng, L):
    y = filt(white(L, rng), 300, 9000, circular=True)
    whine = sine(qf(15700, L), L) * 0.05
    return pk(y) * 0.8 + whine


@loop("EntityDrone", 8.0)
def entity_drone(rng, L):
    t = T(L)
    base = sine(qf(41, L), L) + 0.6 * sine(qf(43.5, L), L) + 0.3 * sine(qf(82, L), L)
    air = filt(brown(L, rng, circular=True), 30, 400, circular=True)
    wob = 0.8 + 0.2 * np.sin(2 * np.pi * qf(0.25, L) * t)
    return (pk(base) * 0.6 + pk(air) * 0.4) * wob
