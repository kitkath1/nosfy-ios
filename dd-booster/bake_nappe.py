# La nappe du manège v2 — BOÎTE À MUSIQUE, pas drone.
# v1 payée : des grains sinus nus = des bips de notification (« on dirait
# un bug » — Kathryn), un accord tenu = un orgue de test. v2 : un motif
# lent de clochettes (mi pentatonique, une note ~3 s), timbre de cloche
# vrai (partiels inharmoniques, attaque 4 ms, décroissance exponentielle),
# paires détunées ±3 cents, noyé de réverbe longue. Boucle 25 s SANS
# COUTURE : fréquences quantifiées au bin, enveloppes circulaires (mod N),
# réverbe en convolution circulaire.
import wave

import numpy as np

SR = 48000
L = 25.0
N = int(SR * L)
rng = np.random.default_rng(7)


def qf(f):
    return round(f * L) / L


def bell(f0, dur, amp):
    """Une clochette : partiels inharmoniques détunés, décroissance expo."""
    ln = int(dur * SR)
    tt = np.arange(ln) / SR
    partials = [(1.0, 1.0, 1.8), (2.0, 0.38, 0.9),
                (2.76, 0.22, 0.5), (5.40, 0.07, 0.22)]
    out = np.zeros(ln)
    for ratio, a, tau in partials:
        for det in (1.00173, 0.99827):  # ±3 cents : le battement magique
            out += a * 0.5 * np.sin(2 * np.pi * qf(f0 * ratio * det) * tt) \
                * np.exp(-tt / tau)
    attack = np.minimum(tt / 0.004, 1)
    return out * attack * amp


# ---- 1. le motif : neuf clochettes sur 25 s, rubato doux ----------------
E5, Fs5, Gs5, B5, Cs6, E6, B4 = 659.26, 739.99, 830.61, 987.77, 1108.73, 1318.51, 493.88
motif = [
    (0.8, E5, 1.0), (3.6, Gs5, 0.8), (6.2, B5, 0.9), (9.4, Fs5, 0.7),
    (12.1, E6, 0.85), (15.2, Cs6, 0.7), (17.8, B5, 0.75), (20.6, Gs5, 0.65),
    (22.9, B4, 0.8),
]
bells = np.zeros((N, 2))
for pos, f, a in motif:
    tone = bell(f, 6.0, a)
    idx = (int(pos * SR) + np.arange(len(tone))) % N  # circulaire
    pan = rng.uniform(0.35, 0.65)
    bells[idx, 0] += tone * np.cos(pan * np.pi / 2)
    bells[idx, 1] += tone * np.sin(pan * np.pi / 2)
bells *= 0.16

# ---- 2. la poussière : rares PLINKS aigus, presque tout en réverbe ------
dust = np.zeros((N, 2))
for _ in range(6):
    f = rng.uniform(2600, 5200)
    tone = bell(f, 1.2, rng.uniform(0.3, 0.6))
    idx = (int(rng.uniform(0, L) * SR) + np.arange(len(tone))) % N
    pan = rng.uniform(0.15, 0.85)
    dust[idx, 0] += tone * np.cos(pan * np.pi / 2)
    dust[idx, 1] += tone * np.sin(pan * np.pi / 2)
dust *= 0.05

# ---- 3. le souffle grave de braise (spectral → périodique), très bas ----
freqs = np.fft.rfftfreq(N, 1 / SR)
shape = np.where((freqs > 18) & (freqs < 130),
                 1.0 / np.maximum(freqs, 20) ** 1.6, 0)
t = np.arange(N) / SR
sub = np.zeros((N, 2))
for ch in range(2):
    spec = shape * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
    s = np.fft.irfft(spec, N)
    sub[:, ch] = s / np.max(np.abs(s))
sub *= (0.6 + 0.4 * np.sin(2 * np.pi * (2 / L) * t + 1.3))[:, None] * 0.030

# ---- 4. la réverbe longue, convolution CIRCULAIRE -----------------------
rt60 = 2.6
ir_len = int(3.2 * SR)
mix = np.zeros((N, 2))
for ch in range(2):
    ir = rng.standard_normal(ir_len) * np.exp(-6.91 * np.arange(ir_len) / SR / rt60)
    ir = np.convolve(ir, np.ones(6) / 6, mode="same")
    IR = np.fft.rfft(ir, N)
    dry = bells[:, ch] + dust[:, ch] * 2.5
    wet = np.fft.irfft(np.fft.rfft(dry) * IR, N)
    wet /= np.max(np.abs(wet)) + 1e-9
    mix[:, ch] = bells[:, ch] * 0.8 + dust[:, ch] * 0.3 + sub[:, ch] + wet * 0.16

# ---- 5. master ----------------------------------------------------------
mix /= np.max(np.abs(mix))
mix *= 10 ** (-13 / 20)
pcm = (mix * 32767).astype("<i2")
with wave.open("/tmp/manege-nappe.wav", "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("ok | couture max :", float(np.max(np.abs(mix[0] - mix[-1]))))
