"""
Player sounds: material footsteps (6 variations each), jumps, landings,
doors (7 door types x 6 actions) and world interactions.
"""

import numpy as np

from dsp import (
    Mix, T, beep, bell, bump, chime, crackle, creak, env_perc, env_pts, filt, formant_filter,
    gate, hz, modes, motor, noise_hit, pk, reverb, rustle, saturate, sine, smooth, softsq,
    sparkle, sweep, thump, tick, tri, white, zeros, voice, VOWELS,
)

RECIPES = {}
LOOPS = {}

STEP_VARIATIONS = 6


def reg(path, variations=1):
    def wrap(fn):
        RECIPES[path] = (fn, variations)
        return fn
    return wrap


# ---------------------------------------------------------------------------
# FOOTSTEPS
# ---------------------------------------------------------------------------

def footstep(rng, thud_f=110, thud_dec=0.025, click_lo=400, click_hi=6000, click_dec=0.008,
             scrape=(2500, 9000, 0.25), body=None, toe=0.55, d=0.26):
    j = 1 + rng.uniform(-0.08, 0.08)
    m = Mix()
    m.add(thump(rng, thud_f * j, thud_dec, d, 0.4), 0, 0.8)
    m.add(noise_hit(rng, d, click_lo * j, click_hi * j, click_dec * rng.uniform(0.8, 1.2)), 0, 1.0)
    roll = rng.uniform(0.03, 0.06)
    m.add(noise_hit(rng, d, click_lo * j * 1.2, click_hi * j, click_dec * 0.8), roll, toe * rng.uniform(0.6, 1.0))
    if scrape:
        lo, hi, g = scrape
        s = filt(white(d, rng), lo, hi) * bump(d, rng.uniform(0.02, 0.07), rng.uniform(0.01, 0.025))
        m.add(pk(s), 0, g * rng.uniform(0.6, 1.2))
    if body:
        freqs, decays, amps = body
        b = modes(d, [f * j for f in freqs], decays, amps, rng, 0.04)
        m.add(pk(b), 0.0, 0.6)
        m.add(pk(b) * 0.5, roll, 0.4)
    return m.render(d)


def squeak(rng, d=0.05):
    f0 = rng.uniform(1300, 1600)
    y = softsq(sweep(f0, f0 * 1.3, d), d, 1.5) * gate(d, 0.008, 0.015)
    return filt(y, 800, 6000)


@reg("Player.Footstep.Concrete", STEP_VARIATIONS)
def step_concrete(rng, v):
    return footstep(rng, 110, 0.025, 400, 6000, 0.008, (2500, 9000, 0.3))


@reg("Player.Footstep.Wood", STEP_VARIATIONS)
def step_wood(rng, v):
    y = footstep(rng, 140, 0.04, 300, 3000, 0.01, (1500, 5000, 0.12),
                 body=([210, 480, 950], [0.06, 0.04, 0.025], [1, 0.6, 0.3]), d=0.3)
    if v in (1, 4):
        y = Mix().add(y).add(creak(rng, 0.16, (60, 110), ((520, 0.01), (1100, 0.006))), 0.05, 0.25).render()
    return y


@reg("Player.Footstep.Metal", STEP_VARIATIONS)
def step_metal(rng, v):
    y = footstep(rng, 90, 0.03, 800, 9000, 0.006, (3000, 9000, 0.15),
                 body=([430, 1120, 1980, 3170, 4400], [0.15, 0.1, 0.07, 0.05, 0.03], [0.6, 0.5, 0.4, 0.25, 0.15]), d=0.45)
    rattle = filt(white(0.2, rng), 1500, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(40, 70) * T(0.2))) * env_perc(0.2, 0.002, 0.05)
    return Mix().add(y).add(pk(rattle), 0.01, 0.2).render()


@reg("Player.Footstep.Tile", STEP_VARIATIONS)
def step_tile(rng, v):
    return footstep(rng, 120, 0.02, 1500, 10000, 0.005, (4000, 10000, 0.1),
                    body=([1900, 3300], [0.015, 0.01], [1, 0.6]), toe=0.8, d=0.22)


@reg("Player.Footstep.Carpet", STEP_VARIATIONS)
def step_carpet(rng, v):
    y = footstep(rng, 90, 0.04, 150, 1200, 0.015, (300, 2000, 0.35), toe=0.4, d=0.24)
    return filt(y, None, 2500)


@reg("Player.Footstep.Water", STEP_VARIATIONS)
def step_water(rng, v):
    d = 0.35
    m = Mix()
    t = T(d)
    env = np.zeros_like(t)
    for _ in range(3):
        env += rng.uniform(0.4, 1) * np.exp(-0.5 * ((t - rng.uniform(0.01, 0.12)) / rng.uniform(0.015, 0.04)) ** 2)
    m.add(pk(filt(white(d, rng), 400, 5000) * env), 0, 1)
    for _ in range(rng.integers(4, 8)):
        dd = 0.035
        f0 = rng.uniform(700, 1500)
        m.add(sine(sweep(f0, f0 * 1.8, dd), dd) * env_perc(dd, 0.001, 0.012), rng.uniform(0.02, 0.22), rng.uniform(0.15, 0.4))
    m.add(thump(rng, 150, 0.03, 0.15, 0.6), 0, 0.4)
    return m.render(d)


@reg("Player.Footstep.Grass", STEP_VARIATIONS)
def step_grass(rng, v):
    d = 0.28
    m = Mix().add(thump(rng, 90, 0.03, d, 0.3), 0, 0.5)
    c = crackle(rng, d, 900, 2000, 9000) * bump(d, 0.06, 0.035)
    m.add(pk(c), 0, 0.8)
    m.add(rustle(rng, d, 1500, 7000, 3), 0, 0.35)
    return m.render(d)


@reg("Player.Footstep.Glass", STEP_VARIATIONS)
def step_glass(rng, v):
    d = 0.35
    m = Mix().add(footstep(rng, 110, 0.02, 800, 8000, 0.006, None, d=0.2), 0, 0.7)
    m.add(pk(crackle(rng, 0.12, 1500, 3000, 12000)), 0.005, 0.6)
    for _ in range(rng.integers(3, 7)):
        f = rng.uniform(3500, 9000)
        m.add(tick(rng, [f, f * 1.47], [rng.uniform(0.02, 0.06), 0.015], click=0.3), rng.uniform(0.0, 0.1), rng.uniform(0.15, 0.4))
    return m.render(d)


@reg("Player.Footstep.Hospital", STEP_VARIATIONS)
def step_hospital(rng, v):
    y = footstep(rng, 120, 0.02, 1000, 8000, 0.006, (3000, 8000, 0.1), toe=0.7, d=0.24)
    if v in (2, 5):
        y = Mix().add(y).add(squeak(rng), 0.04, 0.35).render()
    return y


@reg("Player.Footstep.School", STEP_VARIATIONS)
def step_school(rng, v):
    y = footstep(rng, 130, 0.03, 600, 6000, 0.008, (2000, 7000, 0.15),
                 body=([260, 610], [0.03, 0.02], [1, 0.5]), d=0.26)
    if v == 3:
        y = Mix().add(y).add(squeak(rng, 0.06), 0.05, 0.3).render()
    return y


@reg("Player.Jump", 2)
def jump(rng, v):
    m = Mix().add(noise_hit(rng, 0.08, 1000, 6000, 0.02), 0, 0.5)
    d = 0.25
    whoosh = filt(white(d, rng), 300, 3000) * env_pts(d, [(0, 0), (0.08, 1), (d, 0)])
    m.add(pk(whoosh), 0.02, 0.5)
    return m.render()


@reg("Player.Land", 2)
def land(rng, v):
    m = Mix().add(thump(rng, 75, 0.07, 0.35, 0.5), 0, 1)
    m.add(noise_hit(rng, 0.2, 400, 6000, 0.01), 0, 0.5)
    m.add(rustle(rng, 0.2, 500, 4000, 2), 0.01, 0.25)
    return m.render()


@reg("Player.HeavyLand")
def heavy_land(rng, v):
    m = Mix().add(thump(rng, 55, 0.14, 0.6, 0.6), 0, 1)
    m.add(thump(rng, 110, 0.08, 0.4, 0.4), 0, 0.5)
    m.add(noise_hit(rng, 0.3, 50, 1500, 0.09), 0, 0.6)
    for _ in range(5):
        m.add(tick(rng, [rng.uniform(1500, 4000)], [0.01], click=0.5), rng.uniform(0.03, 0.25), rng.uniform(0.05, 0.15))
    return saturate(m.render(), 1.4)


# ---------------------------------------------------------------------------
# DOORS
# ---------------------------------------------------------------------------

DOOR_TYPES = {
    "Wood": dict(modes=[95, 210, 440, 780], decays=[0.18, 0.12, 0.08, 0.05], latch=[2600, 4300],
                 creak=((420, 0.012), (950, 0.008), (1800, 0.004)), rattle=0.1, boom=70),
    "Metal": dict(modes=[75, 180, 390, 820, 1560, 2700], decays=[0.45, 0.35, 0.3, 0.2, 0.15, 0.1], latch=[3100, 5200],
                  creak=((700, 0.02), (1600, 0.012), (3100, 0.006)), rattle=0.3, boom=55),
    "Security": dict(modes=[55, 130, 290, 640, 1300, 2300], decays=[0.6, 0.45, 0.35, 0.25, 0.18, 0.12], latch=[1800, 3600],
                     creak=((600, 0.025), (1350, 0.015), (2700, 0.008)), rattle=0.2, boom=45, bolt=True),
    "Hospital": dict(modes=[85, 200, 470, 1050, 2200], decays=[0.3, 0.22, 0.15, 0.1, 0.07], latch=[2200, 3900],
                     creak=((550, 0.015), (1250, 0.01), (2400, 0.005)), rattle=0.15, boom=60, pushbar=True),
    "School": dict(modes=[100, 230, 520, 1100], decays=[0.2, 0.14, 0.09, 0.06], latch=[2400, 4100],
                   creak=((480, 0.014), (1000, 0.009), (2000, 0.005)), rattle=0.12, boom=65, pushbar=True),
    "Motel": dict(modes=[130, 300, 650], decays=[0.12, 0.08, 0.05], latch=[2800, 4600],
                  creak=((380, 0.012), (880, 0.008), (1700, 0.004)), rattle=0.25, boom=80, chain=True),
    "Locker": dict(modes=[260, 610, 1150, 1900, 3050], decays=[0.25, 0.2, 0.15, 0.1, 0.07], latch=[3400, 5600],
                   creak=((900, 0.015), (2100, 0.008), (3800, 0.005)), rattle=0.6, boom=110),
}


def door_body(rng, p, strength=1.0, decay_scale=1.0, d=1.2):
    decays = [x * decay_scale for x in p["decays"]]
    amps = [1.0 / (1 + i * 0.6) for i in range(len(p["modes"]))]
    return pk(modes(d, p["modes"], decays, amps, rng, 0.03)) * strength


def door_rattle(rng, p, d=0.35):
    if p["rattle"] <= 0:
        return zeros(d)
    t = T(d)
    am = (np.sin(2 * np.pi * rng.uniform(18, 30) * t) > 0.3).astype(float)
    y = filt(white(d, rng), 800, 6000) * am * env_perc(d, 0.002, d * 0.3)
    return pk(y) * p["rattle"]


def door_latch(rng, p, gain=1.0):
    return tick(rng, p["latch"], [0.012, 0.007], click=0.8) * gain


def chain_rattle(rng, d=0.3):
    m = Mix()
    for _ in range(8):
        f = rng.uniform(2500, 6000)
        m.add(tick(rng, [f, f * 1.6], [0.02, 0.012], click=0.4), rng.uniform(0, d * 0.8), rng.uniform(0.2, 0.5))
    return m.render(d)


def door_handle(rng, p):
    m = Mix()
    if p.get("pushbar"):
        m.add(tick(rng, [700, 1500, 2900], [0.03, 0.02, 0.01], click=0.7), 0, 1)
        m.add(door_latch(rng, p, 0.8), 0.05, 1)
    else:
        m.add(door_latch(rng, p, 0.8), 0, 1)
        m.add(tick(rng, [p["latch"][0] * 0.8], [0.01], click=0.6), 0.07, 0.6)
    if p.get("bolt"):
        d = 0.15
        m.add(motor(rng, 180, d, 3, 0.3) * gate(d, 0.01, 0.02), 0.1, 0.35)
        m.add(tick(rng, [500, 1300, 2600], [0.04, 0.02, 0.01], click=0.8), 0.26, 0.9)
    return m.render()


def make_door(type_name, p):
    base = f"Door.{type_name}"

    @reg(base + ".Handle")
    def handle(rng, v):
        return door_handle(rng, p)

    @reg(base + ".Open", 2)
    def open_(rng, v):
        m = Mix().add(door_handle(rng, p), 0, 0.6)
        start = 0.3 if p.get("bolt") else 0.12
        dur = rng.uniform(0.6, 1.0)
        m.add(creak(rng, dur, (20, 60), p["creak"]), start, 0.45)
        m.add(filt(white(dur, rng), 60, 700) * env_pts(dur, [(0, 0), (dur * 0.5, 1), (dur, 0)]), start, 0.15)
        m.add(door_body(rng, p, 0.2, 0.5), start, 1)
        if p.get("chain"):
            m.add(chain_rattle(rng), start + 0.1, 0.4)
        return m.render()

    @reg(base + ".Close", 2)
    def close(rng, v):
        m = Mix()
        m.add(door_body(rng, p, 0.6, 0.6), 0, 1)
        m.add(filt(noise_hit(rng, 0.2, 60, 2500, 0.015), None, 3000), 0, 0.5)
        m.add(door_latch(rng, p), 0.035, 0.9)
        m.add(door_rattle(rng, p), 0.02, 0.4)
        if p.get("chain"):
            m.add(chain_rattle(rng, 0.2), 0.02, 0.3)
        return m.render()

    @reg(base + ".Slam", 2)
    def slam(rng, v):
        m = Mix()
        m.add(noise_hit(rng, 0.4, 60, 9000, 0.03), 0, 1.0)
        m.add(door_body(rng, p, 1.0, 1.5, 1.8), 0, 1.0)
        m.add(thump(rng, p["boom"], 0.25, 1.2, 0.6), 0, 0.9)
        m.add(door_latch(rng, p), 0.01, 0.8)
        m.add(door_rattle(rng, p, 0.6), 0.02, 0.8)
        if p.get("chain"):
            m.add(chain_rattle(rng, 0.4), 0.02, 0.6)
        y = saturate(m.render(), 1.6)
        return reverb(y, rng, rt=0.7, wet=0.18)

    @reg(base + ".Locked")
    def locked(rng, v):
        m = Mix()
        for i in range(3):
            at = i * 0.18 + rng.uniform(-0.02, 0.02)
            m.add(door_latch(rng, p, 0.7), at, 1)
            m.add(door_body(rng, p, 0.35, 0.3, 0.3), at + 0.01, 1)
            m.add(door_rattle(rng, p, 0.15), at + 0.01, 0.6)
        if p.get("bolt"):
            d = 0.3
            m.add(filt(softsq(150, d, 4), None, 2500) * gate(d, 0.005, 0.02), 0.62, 0.5)  # maglock deny buzz
        return m.render()

    @reg(base + ".Creak", 2)
    def creak_(rng, v):
        d = rng.uniform(1.1, 1.6)
        return creak(rng, d, (12, 40), p["creak"], wobble=1.5)


for _name, _params in DOOR_TYPES.items():
    make_door(_name, _params)


# ---------------------------------------------------------------------------
# INTERACTIONS
# ---------------------------------------------------------------------------

@reg("Interaction.BatteryPickup")
def battery_pickup(rng, v):
    m = Mix().add(tick(rng, [1600, 3200], [0.02, 0.01], click=0.8), 0, 1)
    m.add(tick(rng, [5200], [0.03], click=0.2), 0.03, 0.4)
    m.add(rustle(rng, 0.2, 800, 4000, 2), 0.03, 0.25)
    return m.render()


@reg("Interaction.BatteryUse")
def battery_use(rng, v):
    m = Mix().add(filt(white(0.12, rng), 1000, 5000) * gate(0.12, 0.02, 0.04), 0, 0.4)
    m.add(tick(rng, [2300, 4100], [0.012, 0.007], click=0.8), 0.12, 1)
    d = 0.08
    m.add(sine(sweep(800, 1600, d), d) * gate(d, 0.005, 0.02), 0.18, 0.3)
    return m.render()


@reg("Interaction.EvidenceCollect")
def evidence(rng, v):
    d = 0.3
    m = Mix().add(filt(white(d, rng), 2000, 8000) * bump(d, 0.1, 0.05), 0, 0.3)
    m.add(bell(rng, hz(91), 0.8, amps=(1, 0.3, 0.2, 0.08, 0.03)), 0.08, 1)
    return m.render()


@reg("Interaction.Upgrade")
def upgrade(rng, v):
    m = Mix()
    for i in range(4):
        m.add(tick(rng, [1800, 3400], [0.008, 0.005], click=0.7), i * 0.05, 0.3)
    m.add(chime(rng, [hz(79), hz(84), hz(88), hz(91)], 0.08, 0.8, "bell"), 0.15, 1)
    m.add(sparkle(rng, 0.9, 10), 0.35, 0.3)
    return reverb(m.render(), rng, rt=0.8, wet=0.2)


@reg("Interaction.Purchase")
def purchase(rng, v):
    m = Mix()
    m.add(tick(rng, [2800, 6100, 9200], [0.08, 0.05, 0.03], click=0.3), 0, 0.8)
    m.add(tick(rng, [3100, 6800, 9900], [0.08, 0.05, 0.03], click=0.3), 0.06, 0.7)
    m.add(bell(rng, hz(93), 0.7, amps=(1, 0.3, 0.2, 0.1, 0.05)), 0.12, 0.9)
    return m.render()


LOCKER = DOOR_TYPES["Locker"]


@reg("Interaction.LockerOpen")
def locker_open(rng, v):
    m = Mix().add(door_latch(rng, LOCKER), 0, 1)
    m.add(door_rattle(rng, LOCKER, 0.3), 0.03, 0.6)
    m.add(creak(rng, 0.35, (40, 90), LOCKER["creak"]), 0.08, 0.35)
    return m.render()


@reg("Interaction.LockerClose")
def locker_close(rng, v):
    m = Mix().add(door_body(rng, LOCKER, 1.0, 1.0, 0.8), 0, 1)
    m.add(noise_hit(rng, 0.2, 200, 8000, 0.01), 0, 0.6)
    m.add(door_latch(rng, LOCKER), 0.02, 0.9)
    m.add(door_rattle(rng, LOCKER, 0.4), 0.02, 0.8)
    return saturate(m.render(), 1.3)


def slide(rng, d, lo=400, hi=3000):
    t = T(d)
    rough = 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(60, 120) * t + 3 * smooth(d, 10, rng))
    return pk(filt(white(d, rng), lo, hi) * rough * env_pts(d, [(0, 0), (d * 0.2, 1), (d * 0.8, 0.8), (d, 0)]))


@reg("Interaction.DrawerOpen")
def drawer_open(rng, v):
    m = Mix().add(slide(rng, 0.42), 0, 0.7)
    m.add(tick(rng, [220, 540, 1200], [0.04, 0.025, 0.01], click=0.5), 0.42, 0.7)
    m.add(tick(rng, [2400, 3900], [0.02, 0.01], click=0.4), 0.44, 0.2)
    return m.render()


@reg("Interaction.DrawerClose")
def drawer_close(rng, v):
    m = Mix().add(slide(rng, 0.3), 0, 0.6)
    m.add(tick(rng, [200, 500, 1100], [0.05, 0.03, 0.012], click=0.7), 0.3, 1)
    return m.render()


@reg("Interaction.ElevatorButton")
def elevator_button(rng, v):
    return Mix().add(tick(rng, [2600, 4800], [0.008, 0.005], click=0.7), 0, 1).add(beep(1200, 0.08, "sine"), 0.03, 0.4).render()


@reg("Interaction.ElevatorDing")
def elevator_ding(rng, v):
    y = bell(rng, 1480, 2.0, partials=(1, 2.0, 2.9, 4.2, 5.4), amps=(1, 0.5, 0.35, 0.2, 0.1), strike=0.1)
    return reverb(y, rng, rt=1.2, wet=0.2)


@reg("Interaction.Computer")
def computer(rng, v):
    m = Mix().add(beep(1000, 0.15, "softsq", 1.5), 0, 0.5)
    for _ in range(rng.integers(8, 13)):
        m.add(tick(rng, [rng.uniform(1500, 3500)], [0.004], click=0.7), rng.uniform(0.2, 0.75), rng.uniform(0.2, 0.5))
    d = 0.9
    m.add(filt(white(d, rng), 200, 1500) * gate(d, 0.2, 0.2), 0, 0.08)
    return m.render()


@reg("Interaction.KeyPickup")
def key_pickup(rng, v):
    m = Mix()
    for _ in range(rng.integers(6, 10)):
        f = rng.uniform(3000, 7000)
        m.add(tick(rng, [f, f * 1.53], [rng.uniform(0.05, 0.12), 0.03], click=0.3), rng.uniform(0, 0.25), rng.uniform(0.3, 0.8))
    return m.render()


@reg("Interaction.Unlock")
def unlock(rng, v):
    m = Mix().add(filt(white(0.12, rng), 2000, 7000) * gate(0.12, 0.01, 0.03), 0, 0.3)
    for i in range(3):
        m.add(tick(rng, [3500, 6000], [0.005, 0.003], click=0.7), 0.14 + i * 0.05, 0.5)
    m.add(tick(rng, [700, 1600, 2900], [0.04, 0.02, 0.01], click=0.8), 0.35, 1)
    return m.render()


@reg("Interaction.GeneratorStart")
def generator(rng, v):
    m = Mix()
    for at in (0.0, 0.55):
        d = 0.3
        pull = filt(white(d, rng), 600, 4000) * env_pts(d, [(0, 0), (0.05, 1), (d, 0)])
        m.add(pk(pull), at, 0.5)
        m.add(thump(rng, 90, 0.05, 0.2), at + 0.25, 0.4)
    d = 2.2
    rate = env_pts(d, [(0, 7), (0.8, 18), (d, 24)])
    ph = np.cumsum(rate / 44100)
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    imp = np.zeros(int(d * 44100))
    imp[idx] = 1
    pulse = thump(rng, 70, 0.03, 0.12, 0.8)
    from dsp import fftconv
    engine = fftconv(imp, pulse)[: len(imp)]
    clatter = filt(white(d, rng), 2500, 7000) * (0.4 + 0.6 * smooth(d, 30, rng))
    body = pk(engine) + 0.15 * pk(clatter)
    body *= env_pts(d, [(0, 0.3), (0.6, 1), (d - 0.3, 1), (d, 0)])
    m.add(saturate(body, 1.5), 1.0, 1)
    return m.render()


@reg("Interaction.BreakerOn")
def breaker_on(rng, v):
    m = Mix().add(tick(rng, [400, 900, 2100], [0.05, 0.03, 0.015], click=1.0), 0, 1)
    d = 0.6
    hum = (sine(60, d) + 0.6 * sine(120, d) + 0.3 * softsq(180, d, 2)) * env_perc(d, 0.02, 0.2)
    m.add(pk(hum), 0.02, 0.6)
    m.add(pk(crackle(rng, 0.12, 400)), 0.01, 0.3)
    return saturate(m.render(), 1.3)


@reg("Interaction.BreakerOff")
def breaker_off(rng, v):
    m = Mix().add(tick(rng, [380, 850, 2000], [0.05, 0.03, 0.015], click=1.0), 0, 1)
    d = 0.6
    hum = sine(sweep(120, 40, d), d) * env_perc(d, 0.005, 0.2)
    m.add(hum, 0.01, 0.5)
    return m.render()


def radio_band(x):
    return saturate(filt(x, 300, 3200, 3), 2.0)


@reg("Interaction.RadioStatic", 2)
def radio_static(rng, v):
    d = 1.6
    t = T(d)
    s = filt(white(d, rng), 300, 5000) * (0.6 + 0.4 * smooth(d, 12, rng))
    s = pk(s) + 0.5 * pk(crackle(rng, d, 200))
    whistle = sine(1200 + 1400 * smooth(d, 1.5, rng), d) * 0.15
    m = Mix().add(pk(s + whistle) * gate(d, 0.02, 0.01), 0, 1)
    m.add(filt(white(0.12, rng), 800, 6000) * gate(0.12, 0.002, 0.004), d, 0.9)  # squelch tail
    return m.render()


def babble(rng, d, f0=130, rate=4.5, scale=1.0):
    seq = []
    vowels = list(VOWELS.keys())
    count = max(2, int(d * rate))
    for i in range(count + 1):
        seq.append((d * i / count, vowels[rng.integers(0, len(vowels))]))
    f = f0 * (1 + 0.12 * (smooth(d, 3, rng) - 0.5))
    y = voice(rng, d, f, seq, 0.25, scale)
    t = T(d)
    syll = 0.25 + 0.75 * (np.sin(2 * np.pi * rate * t + rng.uniform(0, 6)) > -0.3)
    return filt(y * syll, None, 4000)


@reg("Interaction.RadioVoice", 2)
def radio_voice(rng, v):
    d = 2.4
    y = radio_band(babble(rng, d, rng.uniform(110, 150)) * gate(d, 0.05, 0.1))
    s = filt(white(d, rng), 300, 5000) * 0.25 + 0.3 * crackle(rng, d, 150)
    return pk(y + pk(s) * 0.3)


@reg("Interaction.PhoneRing")
def phone_ring(rng, v):
    d = 2.0
    ring_d = 1.6
    m = Mix()
    b1 = bell(rng, 1040, 0.3, partials=(1, 2.3, 3.9), decays=[0.2, 0.1, 0.05], amps=(1, 0.4, 0.2), strike=0.3)
    b2 = bell(rng, 1300, 0.3, partials=(1, 2.3, 3.9), decays=[0.2, 0.1, 0.05], amps=(1, 0.4, 0.2), strike=0.3)
    i = 0
    at = 0.0
    while at < ring_d:
        m.add(b1 if i % 2 == 0 else b2, at, 0.7)
        at += 1 / 20
        i += 1
    y = m.render(d)
    return y * env_pts(d, [(0, 1), (ring_d, 1), (d, 0)])


@reg("Interaction.PhonePickup")
def phone_pickup(rng, v):
    m = Mix()
    for at in (0.0, 0.05, 0.11):
        m.add(tick(rng, [900, 2200, 4000], [0.02, 0.01, 0.006], click=0.6), at, rng.uniform(0.5, 1))
    m.add(tick(rng, [3000, 5200], [0.006, 0.004], click=0.8), 0.2, 0.6)
    d = 0.5
    m.add((sine(350, d) + sine(440, d)) * gate(d, 0.01, 0.05), 0.3, 0.12)
    return m.render()
