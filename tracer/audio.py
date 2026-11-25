"""Synthesised soundtrack for the whole film. Every sound is placed from the same event times the pictures use
(shot start on the edit timeline + the event's time inside the shot). No recordings, no music library."""
import sys, wave
import numpy as np

SR = 48000
DUR = 24.4
rng = np.random.default_rng(11)
n = int(SR * DUR)
t = np.arange(n) / SR
L = np.zeros(n); R = np.zeros(n)

# edit timeline: shot starts (seconds)
S1, S2, S3, S4, S5, S6, S7, END = 0.0, 2.6, 4.9, 6.9, 8.7, 12.2, 15.8, 19.8


def add(sig, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    if i >= n or i < 0: return
    j = min(n, i + len(sig)); s = sig[: j - i] * gain
    L[i:j] += s * (1.0 - 0.5 * max(pan, 0)); R[i:j] += s * (1.0 + 0.5 * min(pan, 0))


def lp(x, k):
    w = np.exp(-np.arange(int(6 * k)) / k); return np.convolve(x, w / w.sum(), "same")


def clack(partials, length=0.22, click=0.6, body=410.0):
    m = int(SR * length); x = np.arange(m) / SR
    c = rng.normal(0, 1, m) * np.exp(-x * 900)
    ring = sum(a * np.sin(2 * np.pi * f * x + ph) * np.exp(-x * d) for f, a, d, ph in partials)
    return click * c + 0.5 * ring + 0.5 * np.sin(2 * np.pi * body * x) * np.exp(-x * 60)

BRASS = [(1830, 0.9, 38, 0.0), (2710, 0.7, 52, 1.1), (4120, 0.5, 70, 2.0), (5630, 0.35, 95, 0.4), (7480, 0.2, 130, 1.7)]
STEEL = [(2350, 0.9, 30, 0.3), (3620, 0.7, 44, 1.4), (5210, 0.5, 60, 0.2), (6900, 0.3, 90, 2.2), (9100, 0.2, 120, 0.9)]
IRON = [(640, 0.9, 9, 0.0), (1010, 0.6, 12, 1.0), (1730, 0.4, 16, 2.1), (2480, 0.25, 22, 0.5)]
DOORH = [(1250, 0.8, 55, 0.0), (2100, 0.5, 70, 1.3), (3300, 0.3, 95, 0.7)]


def rattle(length=0.55, rate=14.0, low=92.0, decay=8.0):
    m = int(SR * length); x = np.arange(m) / SR
    noise = lp(rng.normal(0, 1, m), 30.0)
    return (2.2 * noise * (0.5 + 0.5 * np.sin(2 * np.pi * rate * x)) + 0.9 * np.sin(2 * np.pi * low * x) * np.exp(-x * 22)) * np.exp(-x * decay)


def bed(t0, t1, k, gain, fade=0.25):
    i, j = int(t0 * SR), int(t1 * SR); m = j - i; x = np.arange(m) / SR
    s = lp(rng.normal(0, 1, m), k) * np.minimum(1, x / fade) * np.minimum(1, (m / SR - x) / fade)
    add(s, t0, gain, 0.2); add(np.roll(s, 331), t0, gain, -0.2)

# 1. bazaar shutter: brass on steel, thin shutter rattle, lane air
for at, g in [(0.22, 0.75), (0.58, 0.9)]:
    add(clack(BRASS), S1 + at, g, -0.2); add(rattle(), S1 + at + 0.004, 0.5 * g)
add(clack(BRASS, 0.12), S1 + 1.08, 0.16); add(clack(BRASS, 0.10), S1 + 1.53, 0.08)
bed(S1, S2, 90.0, 0.035)
# 2. house gate: steel disc on iron, the gate itself rings low
for at, g in [(0.25, 0.7), (0.60, 0.85)]:
    add(clack(STEEL, 0.2), S2 + at, g, 0.2); add(clack(IRON, 0.9, click=0.2, body=180.0), S2 + at + 0.003, 0.55 * g)
add(clack(STEEL, 0.1), S2 + 1.10, 0.14); add(clack(STEEL, 0.1), S2 + 1.56, 0.07)
bed(S2, S3, 110.0, 0.03)
# 3. safe: dial ticks slowing down, then two dull heavy thuds
tk = S3
for i in range(9):
    add(clack([(5200, 0.8, 300, 0.0)], 0.02, click=0.5, body=2400.0), tk, 0.10); tk += 0.018 + 0.006 * i
for at, g in [(0.53, 0.8), (0.87, 0.95)]:
    m = int(SR * 0.5); x = np.arange(m) / SR
    thud = np.sin(2 * np.pi * 68 * x) * np.exp(-x * 14) + 0.4 * lp(rng.normal(0, 1, m), 60.0) * np.exp(-x * 30) * 4
    add(thud, S3 + at, 0.9 * g); add(clack(DOORH, 0.1, click=0.4), S3 + at, 0.25 * g, 0.3)
bed(S3, S4, 200.0, 0.02)
# 4. factory gate: chain bursts, rain
for at, g in [(0.22, 0.75), (0.55, 0.9)]:
    for k in range(14):
        add(clack(STEEL, 0.07, click=0.5, body=900.0), S4 + at + 0.012 * k + rng.uniform(0, 0.02), g * 0.35 * np.exp(-k * 0.12), rng.uniform(-0.6, 0.6))
i, j = int(S4 * SR), int(S5 * SR); m = j - i; x = np.arange(m) / SR
rain = rng.normal(0, 1, m) - lp(rng.normal(0, 1, m), 6.0)                        # hissy high noise
rain = rain * np.minimum(1, x / 0.12) * np.minimum(1, (m / SR - x) / 0.05)        # cuts off hard into the silence
add(rain, S4, 0.085, 0.1); add(np.roll(rain, 777), S4, 0.085, -0.1)
# 5. empty office: 1.4 s of nothing, then air conditioning and a tube that buzzes when it flickers
i, j = int((S5 + 1.4) * SR), int(S7 * SR); m = j - i; x = np.arange(m) / SR
hum = (np.sin(2 * np.pi * 50 * x) + 0.5 * np.sin(2 * np.pi * 100 * x) + 0.25 * np.sin(2 * np.pi * 150 * x)) * 0.5 + 2.5 * lp(rng.normal(0, 1, m), 160.0)
add(hum * np.minimum(1, x / 1.2) * np.minimum(1, (m / SR - x) / 0.3), S5 + 1.4, 0.045)
for k in range(int((S7 - S5) * 17)):
    h = np.modf(np.sin((k + int(0.3 * 17)) * 91.7) * 4375.85)[0] % 1.0
    if h > 0.80:
        mm = int(SR / 17); xx = np.arange(mm) / SR
        add(np.sign(np.sin(2 * np.pi * 100 * xx)) * lp(rng.normal(0, 1, mm), 4.0) * 0.6, S5 + k / 17.0, 0.02, -0.3)
# 6. the door opens by itself: a long soft hinge sigh, the server fans getting louder
i, j = int((S6 + 0.4) * SR), int((S6 + 2.8) * SR); m = j - i; x = np.arange(m) / SR
sigh = lp(rng.normal(0, 1, m), 12.0) * np.sin(np.pi * x / (m / SR)) ** 2 * (1.0 + 0.4 * np.sin(2 * np.pi * (3 + 2 * x) * x))
add(sigh, S6 + 0.4, 0.16, 0.3)
i, j = int((S6 + 0.4) * SR), int(S7 * SR); m = j - i; x = np.arange(m) / SR
fans = (lp(rng.normal(0, 1, m), 25.0) * 2.0 + 0.3 * np.sin(2 * np.pi * 236 * x) + 0.2 * np.sin(2 * np.pi * 472 * x)) * np.minimum(1, x / 2.4) * np.minimum(1, (m / SR - x) / 0.05)
add(fans, S6 + 0.4, 0.07, 0.3)
# 7. the door is shut: latch, lock chirp, two tugs that hold
m = int(SR * 0.35); x = np.arange(m) / SR
add(np.sin(2 * np.pi * 85 * x) * np.exp(-x * 20) + 0.3 * lp(rng.normal(0, 1, m), 40.0) * np.exp(-x * 40) * 4, S7 + 0.24, 0.8)
m = int(SR * 0.09); x = np.arange(m) / SR
add(np.sin(2 * np.pi * 2960 * x) * np.minimum(1, x / 0.004) * np.minimum(1, (0.09 - x) / 0.01), S7 + 0.32, 0.10, 0.4)
for at, g in [(1.00, 0.75), (1.36, 0.9)]:
    add(clack(DOORH, 0.16, click=0.6, body=300.0), S7 + at, g); add(rattle(0.3, 22.0, 70.0, 14.0), S7 + at + 0.004, 0.3 * g)
bed(S7, END + 0.4, 220.0, 0.022)
# end card: one low swell, a fifth opening to an octave, no melody
i, j = int((END - 0.3) * SR), n; m = j - i; x = np.arange(m) / SR
env = np.minimum(1, x / 1.3) * np.minimum(1, (m / SR - x) / 2.2)
pad = sum(a * np.sin(2 * np.pi * f * x + 0.3 * np.sin(2 * np.pi * 0.21 * x + f)) for f, a in [(73.4, 1.0), (110.0, 0.7), (146.8, 0.55), (220.0, 0.3), (293.7, 0.16)])
add(pad * env, END - 0.3, 0.085, 0.15); add(np.roll(pad, 400) * env, END - 0.3, 0.085, -0.15)

st = np.stack([L, R], 1)
st *= (np.minimum(1, t / 0.04) * np.minimum(1, (DUR - t) / 0.4))[:, None]
peak = np.abs(st).max(); st = st / peak * 0.84
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype("<i2").tobytes())
print("wrote", sys.argv[1], "peak before normalise %.2f" % peak)
