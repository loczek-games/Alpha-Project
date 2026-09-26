"""
Tiny DSP toolkit used by generate_sfx.py.

Everything here is plain numpy: oscillators, noise colours, zero-phase FFT
filters, a short-time (STFT) filter for time-varying spectra (voices,
sweeps), modal "impact" synthesis, envelopes, reverb and loop helpers.
All sounds of CAUGHT ON CAMERA are synthesised from these primitives, so the
audio is 100% original and free of any third-party material.
"""

import numpy as np

SR = 44100
NYQ = SR / 2


# ---------------------------------------------------------------------------
# basics
# ---------------------------------------------------------------------------

def N(d):
    return max(1, int(round(d * SR)))


def T(d):
    return np.arange(N(d)) / SR


def zeros(d):
    return np.zeros(N(d))


def pk(x):
    m = np.max(np.abs(x)) if len(x) else 0
    return x / m if m > 1e-12 else x


def next_pow2(n):
    return 1 << int(np.ceil(np.log2(max(2, n))))


def fit(x, n):
    """Pad / cut an array to exactly n samples."""
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


class Mix:
    """Place signals on a timeline: Mix().add(sig, at, gain).render()"""

    def __init__(self):
        self.parts = []

    def add(self, sig, at=0.0, gain=1.0):
        self.parts.append((np.asarray(sig, dtype=float), max(0.0, at), gain))
        return self

    def render(self, length=None):
        if not self.parts:
            return zeros(length or 0.01)
        end = max(int(round(at * SR)) + len(s) for s, at, _ in self.parts)
        n = N(length) if length else end
        out = np.zeros(n)
        for s, at, g in self.parts:
            i = int(round(at * SR))
            if i >= n:
                continue
            seg = s[: n - i]
            out[i: i + len(seg)] += g * seg
        return out


# ---------------------------------------------------------------------------
# noise & filters
# ---------------------------------------------------------------------------

def white(d, rng):
    return rng.standard_normal(N(d))


def _spectral(x, shape_fn, circular=False):
    n = len(x)
    nfft = n if circular else next_pow2(n + 8192)
    X = np.fft.rfft(x, nfft)
    f = np.fft.rfftfreq(nfft, 1 / SR)
    X *= shape_fn(f)
    return np.fft.irfft(X, nfft)[:n]


def bp_mag(f, lo=None, hi=None, order=2):
    g = np.ones_like(f)
    if hi:
        g = g / np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        g = g / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return g


def filt(x, lo=None, hi=None, order=2, circular=False):
    """Zero-phase Butterworth-magnitude band/low/high-pass."""
    return _spectral(x, lambda f: bp_mag(f, lo, hi, order), circular)


def peaks(x, bands, floor=1.0, circular=False):
    """Add resonant peaks: bands = [(freq, width_hz, gain), ...]"""
    def shape(f):
        g = np.full_like(f, floor)
        for fc, bw, gain in bands:
            g += gain * np.exp(-0.5 * ((f - fc) / bw) ** 2)
        return g
    return _spectral(x, shape, circular)


def pink(d, rng, circular=False):
    x = _spectral(white(d, rng), lambda f: 1 / np.sqrt(np.maximum(f, 20)), circular)
    return x / (np.std(x) + 1e-12)


def brown(d, rng, circular=False):
    x = _spectral(white(d, rng), lambda f: 1 / np.maximum(f, 15), circular)
    return x / (np.std(x) + 1e-12)


def stft_filter(x, gain_fn, nfft=1024, hop=256):
    """Time-varying filter. gain_fn(t_seconds, freqs) -> gains per bin."""
    win = np.hanning(nfft + 1)[:-1]
    pad = nfft
    xp = np.concatenate([np.zeros(pad), x, np.zeros(pad + hop)])
    freqs = np.fft.rfftfreq(nfft, 1 / SR)
    out = np.zeros_like(xp)
    wsum = np.zeros_like(xp)
    for s in range(0, len(xp) - nfft, hop):
        t = (s + nfft / 2 - pad) / SR
        X = np.fft.rfft(xp[s: s + nfft] * win) * gain_fn(t, freqs)
        out[s: s + nfft] += np.fft.irfft(X, nfft) * win
        wsum[s: s + nfft] += win ** 2
    out /= np.maximum(wsum, 1e-3)
    return out[pad: pad + len(x)]


def fftconv(a, b):
    n = len(a) + len(b) - 1
    nfft = next_pow2(n)
    return np.fft.irfft(np.fft.rfft(a, nfft) * np.fft.rfft(b, nfft), nfft)[:n]


# ---------------------------------------------------------------------------
# envelopes & control signals
# ---------------------------------------------------------------------------

def env_perc(d, attack=0.001, decay=0.1):
    t = T(d)
    a = np.clip(t / attack, 0, 1) if attack > 0 else np.ones_like(t)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def env_pts(d, pts):
    """Piecewise-linear envelope from [(time, value), ...]."""
    t = T(d)
    return np.interp(t, [p[0] for p in pts], [p[1] for p in pts])


def gate(d, attack=0.003, release=0.01):
    n = N(d)
    e = np.ones(n)
    a = min(n, N(attack))
    r = min(n, N(release))
    e[:a] *= np.linspace(0, 1, a)
    e[n - r:] *= np.linspace(1, 0, r)
    return e


def bump(d, center, width):
    t = T(d)
    return np.exp(-0.5 * ((t - center) / width) ** 2)


def smooth(d, rate, rng):
    """Smooth random control signal in 0..1 changing about `rate` times/s."""
    n = N(d)
    x = T(d) * rate
    m = int(np.floor(x[-1])) + 3
    pts = rng.random(m)
    i = np.floor(x).astype(int)
    frac = x - i
    w = (1 - np.cos(np.pi * frac)) / 2
    return pts[i] * (1 - w) + pts[i + 1] * w


def fade(x, fin=0.0, fout=0.005):
    x = x.copy()
    a = min(len(x), N(fin)) if fin > 0 else 0
    b = min(len(x), N(fout)) if fout > 0 else 0
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[len(x) - b:] *= np.linspace(1, 0, b)
    return x


# ---------------------------------------------------------------------------
# oscillators
# ---------------------------------------------------------------------------

def _freq(freq, d):
    n = N(d)
    if np.isscalar(freq):
        return np.full(n, float(freq))
    return fit(np.asarray(freq, dtype=float), n)


def phase(freq, d, ph0=0.0):
    return ph0 + 2 * np.pi * np.cumsum(_freq(freq, d)) / SR


def sine(freq, d, ph0=0.0):
    return np.sin(phase(freq, d, ph0))


def tri(freq, d, ph0=0.0):
    return 2 / np.pi * np.arcsin(np.sin(phase(freq, d, ph0)))


def softsq(freq, d, hard=3.0, ph0=0.0):
    return np.tanh(hard * np.sin(phase(freq, d, ph0))) / np.tanh(hard)


def saw(freq, d, max_h=80, ph0=0.0):
    f = _freq(freq, d)
    ph = ph0 + 2 * np.pi * np.cumsum(f) / SR
    k_max = int(min(max_h, NYQ * 0.9 / max(np.max(f), 1)))
    out = np.zeros_like(ph)
    for k in range(1, max(1, k_max) + 1):
        out += ((-1) ** (k + 1)) * np.sin(k * ph) / k
    return out * 2 / np.pi


def sweep(f0, f1, d, curve="exp"):
    t = np.linspace(0, 1, N(d))
    if curve == "exp":
        return f0 * (f1 / f0) ** t
    return f0 + (f1 - f0) * t


def glide(pts, d):
    """Frequency track from [(time, hz), ...]."""
    return env_pts(d, pts)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------------------------------------------------------------------
# building blocks
# ---------------------------------------------------------------------------

def modes(d, freqs, decays, amps=None, rng=None, detune=0.0):
    """Sum of exponentially decaying sine modes (struck object)."""
    t = T(d)
    out = np.zeros_like(t)
    for i, f in enumerate(freqs):
        if rng is not None and detune:
            f = f * (1 + rng.uniform(-detune, detune))
        if f >= NYQ * 0.95:
            continue
        a = amps[i] if amps is not None else 1.0 / (i + 1)
        dec = decays[i] if i < len(decays) else decays[-1]
        ph = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
        out += a * np.sin(2 * np.pi * f * t + ph) * np.exp(-t / dec)
    return out


def tick(rng, freqs, decays, amps=None, click=0.6, lo=1500, hi=12000, clen=0.0025, detune=0.03, dur=None):
    """A struck, resonant object: noise transient + modal body."""
    dur = dur or min(2.5, max(decays) * 7 + 0.01)
    body = pk(modes(dur, freqs, decays, amps, rng, detune))
    burst = pk(filt(white(dur, rng), lo, hi) * env_perc(dur, 0.0002, clen))
    y = body * (1 - click * 0.5) + burst * click
    return fade(y, 0.0003, 0.003)


def noise_hit(rng, d, lo, hi, decay, attack=0.0005):
    return pk(filt(white(d, rng), lo, hi) * env_perc(d, attack, decay))


def thump(rng, f, decay, d=None, noise=0.3):
    d = d or decay * 7
    body = sine(sweep(f * 1.6, f, d), d) * env_perc(d, 0.002, decay)
    n = filt(white(d, rng), 30, f * 4) * env_perc(d, 0.001, decay * 0.6)
    return pk(pk(body) + noise * pk(n))


def beep(freq, d, shape="softsq", hard=2.5, attack=0.003, release=0.012, lp=7000):
    if shape == "sine":
        y = sine(freq, d)
    elif shape == "tri":
        y = tri(freq, d)
    else:
        y = softsq(freq, d, hard)
    y = y * gate(d, attack, release)
    return filt(y, None, lp) if lp else y


def rustle(rng, d, lo=600, hi=5000, density=6, crackle=0.4):
    t = T(d)
    e = np.zeros_like(t)
    for _ in range(density):
        c = rng.uniform(0.1, 0.9) * d
        w = rng.uniform(0.015, 0.06)
        e += rng.uniform(0.4, 1.0) * np.exp(-0.5 * ((t - c) / w) ** 2)
    base = filt(white(d, rng), lo, hi) * e
    spikes = (rng.random(len(t)) < 0.004 * crackle) * rng.standard_normal(len(t))
    spikes = filt(spikes, 2500, 12000) * e
    return pk(pk(base) + 0.5 * pk(spikes))


def creak(rng, d, rate=(20, 60), res=((420, 0.012), (950, 0.008), (1800, 0.004)), wobble=2.5):
    """Stick-slip friction (hinges, floorboards): impulse train into resonators."""
    n = N(d)
    ctl = smooth(d, wobble, rng)
    r = rate[0] + (rate[1] - rate[0]) * ctl
    ph = np.cumsum(r / SR)
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    imp = np.zeros(n)
    imp[idx] = rng.uniform(0.4, 1.0, len(idx))
    ir = modes(0.08, [f for f, _ in res], [dcy for _, dcy in res], rng=rng, detune=0.05)
    y = fftconv(imp, ir)[:n]
    amp = 0.4 + 0.6 * smooth(d, wobble * 1.3, rng)
    return pk(y * amp * gate(d, 0.04, 0.08))


def motor(rng, f_track, d, teeth=6, grit=0.25):
    """Small geared motor (lens, zoom, film advance)."""
    f = _freq(f_track, d)
    tone = softsq(f, d, 2.0) + 0.5 * sine(f * 2.01, d) + 0.25 * sine(f * 3.02, d)
    am = 0.75 + 0.25 * np.sin(phase(f / teeth, d))
    n = filt(white(d, rng), 1500, 7000) * grit
    return pk(filt(tone * am, 80, 6000) + n)


def bell(rng, f, d, partials=(1, 2.0, 2.76, 5.4, 8.9), decays=None, amps=(1, 0.55, 0.4, 0.22, 0.1), strike=0.2):
    decays = decays or [d * 0.45, d * 0.3, d * 0.2, d * 0.12, d * 0.06]
    body = modes(d, [f * p for p in partials], decays, list(amps), rng, 0.002)
    s = noise_hit(rng, d, 2000, 12000, 0.002) * strike
    return fade(pk(pk(body) + s), 0.0005, 0.02)


def musicbox(rng, f, d=1.4):
    return bell(rng, f, d, partials=(1, 2.0, 3.98, 5.9), decays=[0.9, 0.35, 0.18, 0.09], amps=(1, 0.2, 0.18, 0.07), strike=0.08)


def chime(rng, notes, spacing, d_note=0.8, shape="tri"):
    m = Mix()
    for i, f in enumerate(notes):
        if shape == "bell":
            m.add(bell(rng, f, d_note, amps=(1, 0.3, 0.2, 0.08, 0.03)), i * spacing, 1.0)
        else:
            y = (tri(f, d_note) + 0.3 * sine(f * 2, d_note)) * env_perc(d_note, 0.004, d_note * 0.3)
            m.add(pk(y), i * spacing, 1.0)
    return m.render()


def sparkle(rng, d, count=12, lo=3500, hi=9000):
    m = Mix()
    for _ in range(count):
        f = rng.uniform(lo, hi)
        dd = rng.uniform(0.08, 0.25)
        m.add(sine(f, dd) * env_perc(dd, 0.002, dd * 0.3), rng.uniform(0, d * 0.8), rng.uniform(0.2, 1))
    return m.render(d)


def crackle(rng, d, rate=300, lo=1500, hi=10000):
    n = N(d)
    imp = (rng.random(n) < rate / SR) * rng.standard_normal(n)
    return filt(imp, lo, hi)


# ---------------------------------------------------------------------------
# voices (formant synthesis; all unintelligible by design)
# ---------------------------------------------------------------------------

VOWELS = {
    "a": [(800, 80, 1.0), (1150, 90, 0.5), (2900, 120, 0.25)],
    "e": [(400, 70, 1.0), (1700, 100, 0.55), (2600, 120, 0.3)],
    "i": [(300, 60, 1.0), (2300, 100, 0.45), (3000, 120, 0.3)],
    "o": [(450, 70, 1.0), (800, 80, 0.6), (2830, 120, 0.15)],
    "u": [(325, 60, 1.0), (700, 70, 0.4), (2530, 120, 0.1)],
}


def _formants_at(t, seq):
    if t <= seq[0][0]:
        return VOWELS[seq[0][1]]
    for (t0, v0), (t1, v1) in zip(seq, seq[1:]):
        if t0 <= t <= t1:
            w = (t - t0) / max(t1 - t0, 1e-6)
            return [
                (a[0] * (1 - w) + b[0] * w, a[1] * (1 - w) + b[1] * w, a[2] * (1 - w) + b[2] * w)
                for a, b in zip(VOWELS[v0], VOWELS[v1])
            ]
    return VOWELS[seq[-1][1]]


def formant_filter(src, seq, scale=1.0, width=1.0, floor=0.015):
    def gain(t, f):
        g = np.full_like(f, floor)
        for fc, bw, a in _formants_at(t, seq):
            g += a * np.exp(-0.5 * ((f - fc * scale) / (bw * width * 1.6)) ** 2)
        return g
    return stft_filter(src, gain)


def voice(rng, d, f0, seq, breath=0.2, scale=1.0, jitter=0.01):
    f = _freq(f0, d) * (1 + jitter * (smooth(d, 12, rng) - 0.5))
    src = saw(f, d, 60) * (1 - breath) + white(d, rng) * breath * 0.35
    return pk(formant_filter(src, seq, scale))


def whisper(rng, d, syllables=5, scale=1.0):
    seq = []
    vowels = list(VOWELS.keys())
    for i in range(syllables + 1):
        seq.append((d * i / syllables, vowels[rng.integers(0, len(vowels))]))
    src = white(d, rng)
    y = formant_filter(src, seq, scale, width=2.2, floor=0.05)
    y = y + 0.35 * filt(white(d, rng), 3500, 9000)
    # syllable rhythm with breathy "s" edges
    t = T(d)
    env = np.zeros_like(t)
    for i in range(syllables):
        c = (i + 0.5) * d / syllables + rng.uniform(-0.03, 0.03)
        env += rng.uniform(0.5, 1) * np.exp(-0.5 * ((t - c) / (d / syllables * 0.3)) ** 2)
    return pk(y * env * gate(d, 0.05, 0.1))


# ---------------------------------------------------------------------------
# effects
# ---------------------------------------------------------------------------

def reverb(x, rng, rt=0.8, wet=0.25, hi=6000, lo=None, pre=0.012):
    d_ir = rt * 1.1
    ir = white(d_ir, rng) * np.exp(-6.9 * T(d_ir) / rt)
    ir = filt(ir, lo, hi)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
    ir = np.concatenate([np.zeros(N(pre)), ir])
    y = fftconv(x, ir)
    dry = fit(x, len(y))
    return dry * (1 - wet * 0.5) + pk(y) * np.max(np.abs(x)) * wet


def echo(x, taps, lp=None):
    """taps = [(delay_s, gain), ...]; each echo optionally darker."""
    m = Mix().add(x)
    for i, (delay, g) in enumerate(taps):
        e = filt(x, None, lp / (1 + i * 0.5)) if lp else x
        m.add(e, delay, g)
    return m.render()


def saturate(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def crush(x, bits=6, hold=4):
    q = 2 ** (bits - 1)
    y = np.round(x * q) / q
    if hold > 1:
        idx = (np.arange(len(y)) // hold) * hold
        y = y[idx]
    return y


def repitch(x, factor):
    """Resample: factor > 1 = higher and shorter."""
    idx = np.arange(0, len(x) - 1, factor)
    return np.interp(idx, np.arange(len(x)), x)


def ringmod(x, f, mix=0.5):
    return x * (1 - mix) + x * np.sin(2 * np.pi * f * np.arange(len(x)) / SR) * mix


# ---------------------------------------------------------------------------
# loops & finishing
# ---------------------------------------------------------------------------

def fold(x, length):
    """Seamless loop: wrap everything after `length` back onto the start."""
    n = N(length)
    out = fit(x, n).copy()
    tail = x[n:]
    while len(tail):
        k = min(len(tail), n)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def qf(f, length):
    """Quantise a frequency so it completes whole cycles in a loop."""
    return max(1, round(f * length)) / length


def trim_tail(x, floor_db=-66):
    if not len(x):
        return x
    thresh = np.max(np.abs(x)) * 10 ** (floor_db / 20)
    idx = np.nonzero(np.abs(x) > thresh)[0]
    if not len(idx):
        return x[:1]
    return x[: min(len(x), idx[-1] + N(0.01))]


def finish(x, peak=0.89, rms_max=0.22, loop=False):
    x = np.nan_to_num(np.asarray(x, dtype=float))
    x = x - np.mean(x) if loop else x
    if not loop:
        x = fade(trim_tail(x), 0.0, 0.004)
    p = np.max(np.abs(x))
    if p < 1e-9:
        return x
    rms = np.sqrt(np.mean(x ** 2))
    g = min(peak / p, rms_max / max(rms, 1e-9))
    return x * g
