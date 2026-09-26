"""
Equipment sounds: Camera, Flashlight, EMF, Thermal, UV, Night Vision and
generic handling. Each recipe is fn(rng, variation) -> numpy array.
"""

import numpy as np

from dsp import (
    Mix, T, beep, bump, chime, crackle, crush, env_perc, env_pts, filt, gate, hz,
    modes, motor, noise_hit, phase, pk, reverb, rustle, saturate, sine, smooth,
    softsq, sparkle, sweep, thump, tick, tri, white, zeros, qf, fold, saw,
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


# ---------------------------------------------------------------------------
# shared pieces
# ---------------------------------------------------------------------------

def plastic_clack(rng, pitch=1.0, weight=1.0):
    return tick(rng, [1850 * pitch, 3100 * pitch, 5200 * pitch], [0.02 * weight, 0.012, 0.006], [1, 0.6, 0.3], click=0.8)


def metal_clink(rng, pitch=1.0):
    return tick(rng, [2250 * pitch, 5400 * pitch, 8900 * pitch], [0.06, 0.035, 0.02], [1, 0.5, 0.3], click=0.4, detune=0.02)


def equip(rng, clack, rustle_lo=700, reverse=False):
    m = Mix()
    r = rustle(rng, 0.28, rustle_lo, 5000, density=4)
    if reverse:
        m.add(clack, 0.0, 0.9)
        m.add(r, 0.05, 0.45)
    else:
        m.add(r, 0.0, 0.5)
        m.add(clack, 0.17, 1.0)
    return m.render()


def soft_beeps(freqs, d=0.09, gap=0.06, shape="softsq", hard=2.0):
    m = Mix()
    at = 0.0
    for f in freqs:
        m.add(beep(f, d, shape, hard), at, 1.0)
        at += d + gap
    return m.render()


def static_noise(rng, d, lo=300, hi=8000, crack=0.6):
    base = filt(white(d, rng), lo, hi) * (0.55 + 0.45 * smooth(d, 25, rng))
    c = crackle(rng, d, 400, 1500, 11000)
    return pk(pk(base) + crack * pk(c))


def buzz(rng, f, d, hard=3.0, lp=3000, circular=False):
    y = softsq(f, d, hard) + 0.4 * softsq(f * 2, d, hard)
    return pk(filt(y, 60, lp, circular=circular))


# ---------------------------------------------------------------------------
# CAMERA
# ---------------------------------------------------------------------------

@reg("Camera.Equip")
def cam_equip(rng, v):
    m = Mix()
    m.add(equip(rng, plastic_clack(rng)), 0, 1)
    m.add(metal_clink(rng, 1.7), 0.06, 0.12)  # strap buckle
    return m.render()


@reg("Camera.Unequip")
def cam_unequip(rng, v):
    return equip(rng, plastic_clack(rng, 0.9), reverse=True)


@reg("Camera.Shutter", 3)
def cam_shutter(rng, v):
    j = 1 + rng.uniform(-0.03, 0.03)
    m = Mix()
    m.add(tick(rng, [2400 * j, 4100 * j, 6800 * j], [0.018, 0.01, 0.006], [1, 0.6, 0.3], click=1.0, hi=14000), 0, 1.0)
    m.add(motor(rng, 900 * j, 0.03, teeth=3, grit=0.5) * gate(0.03, 0.002, 0.01), 0.012, 0.18)
    m.add(tick(rng, [1900 * j, 3300 * j, 5200 * j], [0.014, 0.009, 0.005], click=0.9), 0.075 + rng.uniform(-0.006, 0.006), 0.85)
    m.add(thump(rng, 140, 0.012, 0.08, 0.5), 0, 0.3)
    return reverb(m.render(), rng, rt=0.25, wet=0.1)


@reg("Camera.Focus")
def cam_focus(rng, v):
    b = beep(3400, 0.045, "sine")
    return Mix().add(b, 0, 1).add(b, 0.07, 1).render()


@reg("Camera.FocusBroken")
def cam_focus_broken(rng, v):
    d = 0.95
    t = T(d)
    wob = 1 + 0.03 * np.sin(2 * np.pi * 7 * t) * (t / d) + 0.06 * (smooth(d, 18, rng) - 0.5) * (t / d)
    tone = softsq(3400 * wob, d, 6.0) * gate(d, 0.004, 0.002)
    stutter = np.where((smooth(d, 40, rng) > 0.25) | (t < 0.5), 1.0, 0.15)
    y = saturate(tone * stutter, 2.5)
    y = filt(y, 300, 9000) + 0.35 * crackle(rng, d, 250) * (t / d)
    tail = static_noise(rng, 0.25) * env_perc(0.25, 0.001, 0.07)
    return Mix().add(pk(y), 0, 1).add(tail, d, 0.6).render()


@reg("Camera.ZoomIn")
def cam_zoom_in(rng, v):
    d = 0.38
    y = motor(rng, sweep(260, 420, d), d, teeth=5) * gate(d, 0.02, 0.03)
    return Mix().add(y, 0, 1).add(tick(rng, [3100, 5200], [0.008, 0.005], click=0.5), d - 0.01, 0.4).render()


@reg("Camera.ZoomOut")
def cam_zoom_out(rng, v):
    d = 0.38
    y = motor(rng, sweep(420, 260, d), d, teeth=5) * gate(d, 0.02, 0.03)
    return Mix().add(y, 0, 1).add(tick(rng, [2700, 4700], [0.008, 0.005], click=0.5), d - 0.01, 0.4).render()


@reg("Camera.LensMove", 2)
def cam_lens(rng, v):
    d = 0.16 + rng.uniform(-0.02, 0.03)
    f0 = rng.uniform(280, 330)
    y = motor(rng, sweep(f0, f0 * 1.2, d), d, teeth=4, grit=0.4) * gate(d, 0.008, 0.02)
    return Mix().add(y, 0, 1).add(tick(rng, [4200], [0.004], click=0.6), d, 0.3).render()


@reg("Camera.ButtonClick")
def cam_button(rng, v):
    m = Mix()
    m.add(tick(rng, [5200, 7600], [0.006, 0.004], click=0.7), 0, 1)
    m.add(tick(rng, [3900], [0.005], click=0.5), 0.045, 0.4)
    return m.render()


@reg("Camera.FlashCharge")
def cam_flash_charge(rng, v):
    d = 1.15
    f = sweep(1800, 8500, d)
    y = sine(f, d) * (0.85 + 0.15 * np.sin(2 * np.pi * 90 * T(d)))
    y *= env_pts(d, [(0, 0), (0.08, 1), (0.9, 0.8), (d, 0)])
    ready = beep(4800, 0.03, "sine") * 0.5
    return Mix().add(y, 0, 1).add(ready, d, 0.6).render()


@reg("Camera.FlashTrigger")
def cam_flash_trigger(rng, v):
    d = 0.2
    m = Mix()
    m.add(noise_hit(rng, d, 200, 16000, 0.006), 0, 1)
    m.add(sine(7200, d) * env_perc(d, 0.0005, 0.025), 0, 0.5)
    m.add(thump(rng, 120, 0.02, 0.12), 0, 0.5)
    m.add(sine(sweep(9500, 8000, d), d) * env_perc(d, 0.002, 0.06), 0.004, 0.15)
    return m.render()


@reg("Camera.BatteryLow")
def cam_batt_low(rng, v):
    return soft_beeps([1500, 1100], 0.1, 0.06)


@reg("Camera.BatteryEmpty")
def cam_batt_empty(rng, v):
    m = Mix().add(soft_beeps([1200, 900, 600], 0.11, 0.05), 0, 1)
    d = 0.45
    m.add(sine(sweep(600, 80, d), d) * env_perc(d, 0.01, 0.15), 0.5, 0.6)
    return m.render()


@reg("Camera.CaptureSuccess")
def cam_capture(rng, v):
    m = Mix()
    m.add(chime(rng, [hz(88), hz(95)], 0.09, 0.7), 0, 1)
    d = 0.35
    m.add(motor(rng, 520, d, teeth=8, grit=0.15) * gate(d, 0.03, 0.08), 0.06, 0.12)  # instant-print whirr
    return m.render()


@reg("Camera.CaptureRare")
def cam_capture_rare(rng, v):
    m = Mix()
    m.add(chime(rng, [hz(84), hz(88), hz(91), hz(96)], 0.07, 1.0, "bell"), 0, 1)
    m.add(sparkle(rng, 1.2, 16), 0.15, 0.35)
    return reverb(m.render(), rng, rt=1.1, wet=0.3)


@reg("Camera.Glitch", 2)
def cam_glitch(rng, v):
    m = Mix()
    at = 0.0
    last = None
    while at < 0.42:
        seg = rng.uniform(0.012, 0.05)
        kind = rng.integers(0, 4)
        if kind == 0:
            s = softsq(rng.uniform(200, 3000), seg, 8) * 0.8
        elif kind == 1:
            s = filt(white(seg, rng), 800, 12000)
        elif kind == 2 and last is not None:
            s = last  # stutter
        else:
            s = zeros(seg)
        last = s
        m.add(s * gate(len(s) / 44100, 0.0005, 0.001), at, 1)
        at += len(s) / 44100
    return pk(crush(m.render(), 5, 6))


@reg("Camera.Static", 2)
def cam_static(rng, v):
    d = 0.6
    return static_noise(rng, d) * gate(d, 0.01, 0.08)


@reg("Camera.Error")
def cam_error(rng, v):
    b = saturate(filt(softsq(180, 0.12, 5), None, 3000) * gate(0.12, 0.003, 0.01), 2)
    return Mix().add(b, 0, 1).add(b, 0.18, 1).render()


# ---------------------------------------------------------------------------
# FLASHLIGHT
# ---------------------------------------------------------------------------

def switch_click(rng, pitch=1.0, latch=True):
    m = Mix()
    m.add(tick(rng, [3200 * pitch, 6100 * pitch], [0.01, 0.006], click=0.8), 0, 1)
    m.add(tick(rng, [900 * pitch], [0.01], click=0.2), 0, 0.3)
    if latch:
        m.add(tick(rng, [2600 * pitch, 4700 * pitch], [0.008, 0.005], click=0.7), 0.012, 0.6)
    return m.render()


@reg("Flashlight.Equip")
def fl_equip(rng, v):
    return equip(rng, metal_clink(rng))


@reg("Flashlight.Unequip")
def fl_unequip(rng, v):
    return equip(rng, metal_clink(rng, 0.9), reverse=True)


@reg("Flashlight.On", 2)
def fl_on(rng, v):
    return switch_click(rng, 1.0 + rng.uniform(-0.03, 0.03))


@reg("Flashlight.Off", 2)
def fl_off(rng, v):
    return switch_click(rng, 0.88 + rng.uniform(-0.03, 0.03))


@reg("Flashlight.ButtonClick")
def fl_button(rng, v):
    return switch_click(rng, 1.1, latch=False)


def spring(rng, f=700, d=0.18):
    t = T(d)
    return sine(f * (1 + 0.08 * np.sin(2 * np.pi * 35 * t)), d) * env_perc(d, 0.001, 0.05)


@reg("Flashlight.BatteryInsert")
def fl_batt_in(rng, v):
    m = Mix()
    for i in range(5):
        m.add(tick(rng, [4200, 7000], [0.004, 0.003], click=0.6), i * 0.05, 0.35)
    m.add(filt(white(0.12, rng), 1000, 4000) * gate(0.12, 0.02, 0.04), 0.28, 0.35)
    m.add(tick(rng, [600, 1400], [0.03, 0.015], click=0.5), 0.4, 1.0)
    m.add(spring(rng), 0.41, 0.45)
    for i in range(3):
        m.add(tick(rng, [4200, 7000], [0.004, 0.003], click=0.6), 0.62 + i * 0.05, 0.3)
    return m.render()


@reg("Flashlight.BatteryRemove")
def fl_batt_out(rng, v):
    m = Mix()
    m.add(spring(rng, 760), 0, 0.5)
    m.add(filt(white(0.14, rng), 1000, 4500) * gate(0.14, 0.02, 0.05), 0.04, 0.4)
    m.add(tick(rng, [700, 1600], [0.025, 0.012], click=0.5), 0.2, 0.8)
    m.add(tick(rng, [900, 2100], [0.02, 0.01], click=0.5), 0.29, 0.5)
    return m.render()


@reg("Flashlight.LowBattery")
def fl_low(rng, v):
    return soft_beeps([1000, 1000], 0.07, 0.07, "sine")


@loop("FlashlightBuzz", 2.0)
def fl_buzz_loop(rng, L):
    f = qf(120, L)
    y = buzz(rng, f, L, 3.5, 3500, circular=True)
    amp = 0.55 + 0.45 * smooth(L, 9, rng)
    amp = fold(np.concatenate([amp, amp[::-1]]), L) * 0.5  # periodic wobble
    n = len(y)
    imp = (rng.random(n) < 120 / 44100) * rng.standard_normal(n)
    c = filt(imp, 2000, 9000, circular=True)
    return y * amp + 0.35 * pk(c)


@reg("Flashlight.Flicker", 2)
def fl_flicker(rng, v):
    m = Mix()
    at = 0.0
    for _ in range(rng.integers(4, 7)):
        m.add(tick(rng, [3000, 5500], [0.005, 0.003], click=0.7), at, rng.uniform(0.3, 0.8))
        seg = rng.uniform(0.03, 0.08)
        m.add(buzz(rng, 120, seg) * gate(seg, 0.002, 0.004), at + 0.004, rng.uniform(0.2, 0.6))
        at += rng.uniform(0.05, 0.12)
    return m.render()


@reg("Flashlight.ElectricalFailure")
def fl_elec_fail(rng, v):
    d = 0.9
    t = T(d)
    arc = filt(white(d, rng), 800, 12000) * (smooth(d, 60, rng) > 0.45) * (t < 0.6)
    hum = buzz(rng, 120, d, 5) * env_pts(d, [(0, 0.2), (0.55, 1), (0.6, 0)])
    m = Mix()
    m.add(pk(arc), 0, 0.7).add(hum, 0, 0.5)
    m.add(tick(rng, [300, 900, 2400], [0.03, 0.02, 0.01], click=1.0), 0.6, 1.0)
    fizz = filt(white(0.4, rng), 3000, 12000) * env_perc(0.4, 0.001, 0.1)
    m.add(fizz, 0.61, 0.4)
    return saturate(m.render(), 1.6)


@reg("Flashlight.BulbFailure")
def fl_bulb_fail(rng, v):
    m = Mix()
    m.add(tick(rng, [5200, 8300], [0.08, 0.05], click=0.3), 0, 0.8)
    m.add(noise_hit(rng, 0.05, 300, 5000, 0.008), 0, 0.6)
    fizz = filt(white(0.3, rng), 4000, 12000) * env_perc(0.3, 0.001, 0.07)
    m.add(fizz, 0.01, 0.35)
    return m.render()


@reg("Flashlight.Interference", 2)
def fl_interference(rng, v):
    d = 0.7
    t = T(d)
    rate = rng.uniform(7, 13)
    f = 240 * (1 + 0.15 * np.sin(2 * np.pi * rate * t))
    y = filt(softsq(f, d, 4), 80, 4000) + 0.5 * static_noise(rng, d)
    return pk(y) * gate(d, 0.03, 0.1)


# ---------------------------------------------------------------------------
# EMF DETECTOR
# ---------------------------------------------------------------------------

@reg("EMF.Equip")
def emf_equip(rng, v):
    return equip(rng, plastic_clack(rng, 0.8))


@reg("EMF.Unequip")
def emf_unequip(rng, v):
    return equip(rng, plastic_clack(rng, 0.75), reverse=True)


@reg("EMF.PowerOn")
def emf_on(rng, v):
    m = Mix().add(beep(880, 0.06), 0, 0.8).add(beep(1320, 0.09), 0.08, 1)
    m.add(filt(white(0.15, rng), 3000, 10000) * env_perc(0.15, 0.002, 0.04), 0, 0.15)
    return m.render()


@reg("EMF.PowerOff")
def emf_off(rng, v):
    d = 0.22
    return softsq(sweep(1320, 620, d), d, 2) * gate(d, 0.004, 0.05)


EMF_LEVELS = {1: (880, 0.09, 1.8), 2: (1046, 0.08, 2.2), 3: (1244, 0.07, 2.8), 4: (1480, 0.06, 3.4), 5: (1760, 0.055, 4.5)}

for _level, (_f, _d, _h) in EMF_LEVELS.items():
    def _make(f=_f, d=_d, h=_h, level=_level):
        def emf_level(rng, v):
            y = beep(f, d, "softsq", h, 0.002, 0.008, 8000)
            return saturate(y, 1.8) if level == 5 else y
        return emf_level
    reg(f"EMF.Level{_level}")(_make())


@reg("EMF.Distort", 2)
def emf_distort(rng, v):
    d = 0.35
    t = T(d)
    f = 1600 + 400 * np.sin(2 * np.pi * rng.uniform(30, 45) * t)
    y = softsq(f, d, 4) * gate(d, 0.003, 0.03)
    return pk(crush(y, 4, 5) + 0.3 * static_noise(rng, d))


@reg("EMF.BrokenBeep", 2)
def emf_broken(rng, v):
    d = 0.26
    t = T(d)
    y = softsq(sweep(1500, 900, d), d, 3) * np.where(np.sin(2 * np.pi * 30 * t) > -0.2, 1, 0.1)
    return y * gate(d, 0.002, 0.001)


# ---------------------------------------------------------------------------
# THERMAL SCANNER
# ---------------------------------------------------------------------------

@reg("Thermal.Equip")
def th_equip(rng, v):
    clack = tick(rng, [900, 2100, 3800], [0.03, 0.015, 0.008], click=0.8)
    return equip(rng, clack)


@reg("Thermal.Unequip")
def th_unequip(rng, v):
    clack = tick(rng, [850, 2000, 3600], [0.03, 0.015, 0.008], click=0.8)
    return equip(rng, clack, reverse=True)


def relay(rng):
    return tick(rng, [1200, 2600, 4800], [0.012, 0.008, 0.004], click=0.9)


@reg("Thermal.Activate")
def th_activate(rng, v):
    d = 0.75
    f = sweep(300, 2400, d)
    whine = (sine(f, d) + 0.3 * sine(f * 2, d)) * env_pts(d, [(0, 0), (0.1, 0.6), (0.7, 0.4), (d, 0)])
    fan = filt(white(d, rng), 300, 2500) * env_pts(d, [(0, 0), (d, 1)])
    m = Mix().add(relay(rng), 0, 0.8).add(pk(whine), 0.02, 0.6).add(pk(fan), 0.02, 0.2)
    m.add(beep(2000, 0.04, "sine"), 0.72, 0.5).add(beep(2600, 0.05, "sine"), 0.79, 0.5)
    return m.render()


@reg("Thermal.Shutdown")
def th_shutdown(rng, v):
    d = 0.65
    f = sweep(2400, 200, d)
    whine = (sine(f, d) + 0.3 * sine(f * 2, d)) * env_pts(d, [(0, 0.5), (d, 0)])
    fan = filt(white(d, rng), 300, 2500) * env_pts(d, [(0, 1), (d, 0)])
    return Mix().add(pk(whine), 0, 0.6).add(pk(fan), 0, 0.2).add(relay(rng), d, 0.7).render()


@loop("ThermalScan", 2.0)
def th_scan_loop(rng, L):
    fan = filt(white(L, rng), 200, 2000, circular=True)
    whine = sine(qf(4000, L), L)
    m = Mix().add(pk(fan), 0, 0.5).add(whine, 0, 0.05)
    for at in (0.5, 1.5):
        m.add(tick(rng, [2600, 4400], [0.006, 0.004], click=0.5), at, 0.35)
    return fold(m.render(L + 0.2), L)


@reg("Thermal.TargetLock")
def th_lock(rng, v):
    m = Mix()
    for i, f in enumerate([1800, 2200, 2700]):
        m.add(beep(f, 0.035, "sine"), i * 0.045, 1)
    return m.render()


@reg("Thermal.HeatDetected")
def th_heat(rng, v):
    m = Mix()
    for i in range(6):
        m.add(beep(800 if i % 2 == 0 else 1200, 0.075, "softsq", 1.5), i * 0.085, 1)
    return m.render()


@reg("Thermal.BatteryWarning")
def th_batt(rng, v):
    return soft_beeps([1400, 1000], 0.08, 0.06)


@reg("Thermal.Interference", 2)
def th_interference(rng, v):
    d = 0.6
    t = T(d)
    f = 900 * (1 + 0.25 * np.sin(2 * np.pi * rng.uniform(15, 30) * t))
    y = sine(f, d) + 0.6 * static_noise(rng, d)
    return pk(y) * gate(d, 0.02, 0.08)


# ---------------------------------------------------------------------------
# UV LIGHT
# ---------------------------------------------------------------------------

def ballast(rng, d, start=9000, end=7000):
    return sine(sweep(start, end, d), d) * env_perc(d, 0.002, d * 0.4)


@reg("UV.Equip")
def uv_equip(rng, v):
    return equip(rng, metal_clink(rng, 0.8))


@reg("UV.Unequip")
def uv_unequip(rng, v):
    return equip(rng, metal_clink(rng, 0.75), reverse=True)


@reg("UV.On", 2)
def uv_on(rng, v):
    m = Mix().add(switch_click(rng, 0.7), 0, 1)
    m.add(ballast(rng, 0.4), 0.01, 0.2)
    m.add(buzz(rng, 100, 0.3, 3, 1500) * env_pts(0.3, [(0, 0), (0.05, 1), (0.3, 0)]), 0.01, 0.35)
    return m.render()


@reg("UV.Off", 2)
def uv_off(rng, v):
    m = Mix().add(switch_click(rng, 0.62), 0, 1)
    m.add(ballast(rng, 0.25, 7000, 4000), 0.0, 0.15)
    return m.render()


@loop("UVHum", 2.0)
def uv_hum_loop(rng, L):
    hum = buzz(rng, qf(100, L), L, 2.5, 1500, circular=True)
    whine = sine(qf(7000, L), L)
    t = T(L)
    am = 0.85 + 0.15 * np.sin(2 * np.pi * qf(3, L) * t)
    return hum * am + 0.06 * whine


@reg("UV.BatteryChange")
def uv_batt(rng, v):
    m = Mix()
    m.add(filt(white(0.14, rng), 800, 4000) * gate(0.14, 0.02, 0.04), 0, 0.4)
    m.add(tick(rng, [650, 1500], [0.03, 0.015], click=0.5), 0.15, 1)
    m.add(tick(rng, [3100, 5300], [0.006, 0.004], click=0.7), 0.3, 0.6)
    return m.render()


@reg("UV.Interference", 2)
def uv_interference(rng, v):
    d = 0.6
    t = T(d)
    f = 100 * (1 + 0.3 * np.sin(2 * np.pi * rng.uniform(5, 9) * t))
    y = buzz(rng, f, d, 5, 2500) + 0.4 * crackle(rng, d, 300)
    return pk(y) * gate(d, 0.02, 0.08)


# ---------------------------------------------------------------------------
# NIGHT VISION  ("BEEP - WHIRR")
# ---------------------------------------------------------------------------

def nv_whirr(d, f0, f1, level=1.0):
    f = sweep(f0, f1, d)
    return sine(f, d) * env_pts(d, [(0, 0), (0.05, level), (d * 0.7, level * 0.6), (d, 0)])


@reg("NightVision.PowerOn")
def nv_on(rng, v):
    m = Mix().add(beep(2400, 0.1, "sine"), 0, 1)
    m.add(nv_whirr(1.3, 500, 11000), 0.15, 0.55)
    m.add(filt(white(1.3, rng), 5000, 12000) * env_perc(1.3, 0.2, 0.4), 0.15, 0.06)
    return m.render()


@reg("NightVision.PowerOff")
def nv_off(rng, v):
    m = Mix().add(nv_whirr(0.8, 11000, 300), 0, 0.55)
    m.add(tick(rng, [3500, 6000], [0.006, 0.004], click=0.7), 0.8, 0.6)
    return m.render()


@reg("NightVision.Activation")
def nv_activation(rng, v):
    return nv_whirr(0.9, 800, 9000)


@loop("NightVisionHum", 2.0)
def nv_hum_loop(rng, L):
    y = sine(qf(7800, L), L) + 0.3 * sine(qf(15600, L), L)
    hiss = filt(white(L, rng), 4000, 12000, circular=True)
    return y * 0.5 + 0.15 * pk(hiss)


@reg("NightVision.BatteryWarning")
def nv_batt(rng, v):
    return soft_beeps([1600, 1600], 0.07, 0.05, "sine")


@reg("NightVision.Static", 2)
def nv_static(rng, v):
    d = 0.45
    return static_noise(rng, d, 500, 9000, 0.8) * gate(d, 0.005, 0.1)


@reg("NightVision.SignalLoss")
def nv_signal_loss(rng, v):
    m = Mix().add(static_noise(rng, 0.35, 300, 9000, 1.0) * gate(0.35, 0.002, 0.02), 0, 1)
    d = 0.4
    m.add(sine(sweep(1200, 200, d), d) * gate(d, 0.003, 0.002), 0.35, 0.7)
    return m.render()


# ---------------------------------------------------------------------------
# HANDLING
# ---------------------------------------------------------------------------

@reg("Equipment.Handling", 2)
def handling(rng, v):
    m = Mix().add(rustle(rng, 0.35, 500, 4500, 5), 0, 0.8)
    m.add(tick(rng, [1300, 2600], [0.02, 0.01], click=0.6), rng.uniform(0.1, 0.25), 0.35)
    return m.render()


@reg("Equipment.Holster", 2)
def holster(rng, v):
    m = Mix().add(rustle(rng, 0.3, 400, 3500, 4), 0, 0.8)
    d = 0.18
    teeth = np.zeros(int(d * 44100))
    step = int(44100 / 90)
    teeth[::step] = 1
    zip_ = filt(teeth, 2000, 7000) * gate(d, 0.01, 0.03)
    m.add(pk(zip_), 0.08, 0.3)
    return m.render()
